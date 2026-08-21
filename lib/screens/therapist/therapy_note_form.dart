import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../../models/patients/nurse_patient_models.dart';
import '../../services/patients/nurse_patient_service.dart';

/// "Daily Notes" tab for physiotherapists and speech therapists.
///
/// A simple free-text area where the therapist records their session notes
/// for the patient. Saved notes are pushed into `patientDetail.therapyNotes`
/// so they appear immediately under History (labelled by therapy type), and
/// the most recent notes are listed below the editor for quick reference.
class TherapyNoteForm extends StatefulWidget {
  final PatientDetail patientDetail;

  /// 'physiotherapist' | 'speech_therapist' — used for labels only; the
  /// server derives the therapy type from the logged-in user.
  final String therapistRole;

  /// Called after a note is saved so parents (e.g. History tab) can refresh.
  final void Function(TherapyNote note)? onNoteSaved;

  const TherapyNoteForm({
    Key? key,
    required this.patientDetail,
    required this.therapistRole,
    this.onNoteSaved,
  }) : super(key: key);

  @override
  State<TherapyNoteForm> createState() => _TherapyNoteFormState();
}

class _TherapyNoteFormState extends State<TherapyNoteForm>
    with AutomaticKeepAliveClientMixin {
  final _service = NursePatientService();
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();

  DateTime _sessionDate = DateTime.now();
  TimeOfDay _sessionTime = TimeOfDay.now();
  bool _isSaving = false;
  int _charCount = 0;

  static const int _maxChars = 10000;

  @override
  bool get wantKeepAlive => true;

  bool get _isSpeech => widget.therapistRole == 'speech_therapist';
  String get _therapyLabel => _isSpeech ? 'Speech Therapy' : 'Physiotherapy';
  Color get _accent => _isSpeech ? const Color(0xFFB45309) : const Color(0xFF0284C7);
  Color get _accentBg => _isSpeech ? const Color(0xFFFFF4E5) : const Color(0xFFE0F2FE);
  IconData get _icon => _isSpeech ? Icons.record_voice_over_outlined : Icons.accessibility_new_rounded;

  List<TherapyNote> get _myRecentNotes {
    final mine = widget.patientDetail.therapyNotes
        .where((n) => n.isOwn || n.therapistRole == widget.therapistRole)
        .toList();
    return mine.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() {
      final len = _noteController.text.length;
      if (len != _charCount) setState(() => _charCount = len);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _sessionDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sessionTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _sessionTime = picked);
  }

  Future<void> _save() async {
    final text = _noteController.text.trim();
    if (text.length < 3) {
      _showSnack('Please write your session notes before saving.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_sessionDate);
      final timeStr =
          '${_sessionTime.hour.toString().padLeft(2, '0')}:${_sessionTime.minute.toString().padLeft(2, '0')}';

      final saved = await _service.createTherapyNote(
        patientId: widget.patientDetail.id,
        note: text,
        sessionDate: dateStr,
        sessionTime: timeStr,
      );

      if (!mounted) return;

      // Show immediately in History without a refetch
      widget.patientDetail.therapyNotes.insert(0, saved);
      widget.onNoteSaved?.call(saved);

      setState(() {
        _noteController.clear();
        _sessionDate = DateTime.now();
        _sessionTime = TimeOfDay.now();
        _isSaving = false;
      });

      _showSnack('$_therapyLabel note saved. It now appears under History.');
    } on NursePatientException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Failed to save note. Please try again.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSessionMeta(),
            const SizedBox(height: 16),
            _buildEditor(),
            const SizedBox(height: 16),
            _buildSaveButton(),
            if (_myRecentNotes.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildRecentNotes(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentBg, _accentBg.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_therapyLabel Session Note',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Record what you did with ${widget.patientDetail.name.split(' ').first} today. '
                  'Your note is saved to the patient\'s history as a $_therapyLabel note.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionMeta() {
    return Row(
      children: [
        Expanded(
          child: _buildMetaChip(
            icon: Icons.calendar_today_outlined,
            label: 'Session date',
            value: DateFormat('EEE, MMM d, yyyy').format(_sessionDate),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetaChip(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: _sessionTime.format(context),
            onTap: _pickTime,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNode.hasFocus ? AppColors.primaryGreen : const Color(0xFFE5E5E5),
          width: _focusNode.hasFocus ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF666666)),
                const SizedBox(width: 8),
                const Text(
                  'Session notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Focus(
            onFocusChange: (_) => setState(() {}),
            child: TextField(
              controller: _noteController,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 9,
              maxLength: _maxChars,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                counterText: '',
                hintText: _isSpeech
                    ? 'e.g. Worked on articulation of /s/ and /r/ sounds, swallowing exercises, '
                        'patient responded well to cueing. Plan: continue twice weekly…'
                    : 'e.g. Gait training 15 mins with walker, range-of-motion exercises for left knee, '
                        'pain 3/10 after session. Plan: progress to stairs next visit…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.5),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final canSave = _charCount >= 3 && !_isSaving;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canSave ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined, size: 20),
        label: Text(
          _isSaving ? 'Saving…' : 'Save $_therapyLabel Note',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRecentNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Your recent notes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            Text(
              'See all in History',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._myRecentNotes.map(_buildRecentNoteCard),
      ],
    );
  }

  Widget _buildRecentNoteCard(TherapyNote note) {
    final dt = note.sessionDateTime;
    final when = dt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(dt)
        : (note.sessionDate ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: _accent, width: 4),
          top: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note.title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _accent),
                ),
              ),
              const Spacer(),
              Text(when, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.note,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}
