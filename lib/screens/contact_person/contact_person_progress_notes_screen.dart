import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/progress_notes/progress_note_models.dart';
import '../../services/contact_person/contact_person_service.dart';

class ContactPersonProgressNotesScreen extends StatefulWidget {
  final int patientId;

  const ContactPersonProgressNotesScreen({
    Key? key,
    required this.patientId,
  }) : super(key: key);

  @override
  ContactPersonProgressNotesScreenState createState() =>
      ContactPersonProgressNotesScreenState();
}

class ContactPersonProgressNotesScreenState
    extends State<ContactPersonProgressNotesScreen>
    with AutomaticKeepAliveClientMixin {
  final _contactPersonService = ContactPersonService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _progressNotes = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortOrder = 'Newest First';

  // Cache management
  DateTime? _lastFetchTime;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProgressNotes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void onTabVisible() {
    final shouldRefresh = _lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) >= _cacheValidityDuration;
    if (shouldRefresh) {
      _loadProgressNotes(silent: true);
    }
  }

  void onTabHidden() {}

  /// Check if cached data is expired
  bool get _isCacheExpired {
    if (_lastFetchTime == null || _progressNotes.isEmpty) return true;
    final difference = DateTime.now().difference(_lastFetchTime!);
    return difference >= _cacheValidityDuration;
  }

  /// Get cache age for display
  String get _cacheAge {
    if (_lastFetchTime == null) return 'Never';
    final difference = DateTime.now().difference(_lastFetchTime!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get cache freshness color
  Color get _cacheFreshnessColor {
    if (_lastFetchTime == null) return Colors.grey;
    final difference = DateTime.now().difference(_lastFetchTime!);

    if (difference < const Duration(minutes: 2)) {
      return const Color(0xFF199A8E);
    } else if (difference < _cacheValidityDuration) {
      return const Color(0xFFFF9A00);
    } else {
      return Colors.red;
    }
  }

  Future<void> _loadProgressNotes({bool silent = false, bool forceRefresh = false}) async {
    // Use cache if valid and not forcing refresh
    if (!forceRefresh && !_isCacheExpired && _progressNotes.isNotEmpty) {
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final notes = await _contactPersonService.getProgressNotes();

      if (mounted) {
        // Convert to List<Map<String, dynamic>>
        List<Map<String, dynamic>> notesList = [];
        for (var note in notes) {
          if (note is Map<String, dynamic>) {
            notesList.add(note);
          } else if (note is Map) {
            notesList.add(Map<String, dynamic>.from(note));
          }
        }

        // Sort notes
        notesList.sort((a, b) {
          final dateA = DateTime.tryParse(a['visit_date'] ?? a['date'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['visit_date'] ?? b['date'] ?? '') ?? DateTime.now();
          return _sortOrder == 'Oldest First' ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });

        // Apply date filters
        if (_startDate != null || _endDate != null) {
          notesList = notesList.where((note) {
            final noteDate = DateTime.tryParse(note['visit_date'] ?? note['date'] ?? '');
            if (noteDate == null) return true;

            if (_startDate != null && noteDate.isBefore(_startDate!)) return false;
            if (_endDate != null && noteDate.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
            return true;
          }).toList();
        }

        setState(() {
          _progressNotes = notesList;
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    _progressNotes.clear();
    _lastFetchTime = null;
    _loadProgressNotes(forceRefresh: true);
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Progress Notes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'Start Date',
                              _startDate,
                              () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    _startDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              'End Date',
                              _endDate,
                              () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    _endDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Sort By',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButton<String>(
                          value: _sortOrder,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: ['Newest First', 'Oldest First'].map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setModalState(() {
                              _sortOrder = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _startDate = null;
                              _endDate = null;
                              _sortOrder = 'Newest First';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF199A8E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? DateFormat('MMM d, yyyy').format(date) : label,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? const Color(0xFF1A1A1A) : Colors.grey[600],
                  fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _startDate != null ||
        _endDate != null ||
        _sortOrder != 'Newest First';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Progress Notes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _cacheFreshnessColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated $_cacheAge',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : const Text(
                'Progress Notes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
        actions: [
          IconButton(
            icon: _isLoading && !_isCacheExpired
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: _isCacheExpired ? Colors.red : const Color(0xFF199A8E),
                  ),
            onPressed: _isLoading ? null : () => _loadProgressNotes(forceRefresh: true),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh progress notes',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  color: Color(0xFF199A8E),
                ),
                onPressed: _showFilterModal,
                tooltip: 'Filter',
              ),
              if (_hasActiveFilters())
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4757),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadProgressNotes(forceRefresh: true),
        color: const Color(0xFF199A8E),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _progressNotes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF199A8E),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_progressNotes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _progressNotes.length,
      itemBuilder: (context, index) {
        return _buildProgressNoteCard(_progressNotes[index]);
      },
    );
  }

  Widget _buildProgressNoteCard(Map<String, dynamic> note) {
    final visitDateStr = note['visit_date'] ?? note['date'] ?? '';
    final visitDate = DateTime.tryParse(visitDateStr) ?? DateTime.now();
    final nurseName = note['nurse']?['name'] ?? 'Unknown Nurse';
    final generalCondition = note['general_condition'] ?? 'N/A';
    final painLevel = note['pain_level'] ?? 0;
    final visitTime = note['visit_time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewFullNoteDetail(note['id'] ?? 0),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF199A8E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF199A8E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Progress Note',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${DateFormat('MMM d, yyyy').format(visitDate)}${visitTime.isNotEmpty ? ' • $visitTime' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF199A8E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFF199A8E),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.health_and_safety,
                            size: 16,
                            color: _getConditionIconColor(generalCondition),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              generalCondition,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.grey[300],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.sentiment_satisfied_alt,
                          size: 16,
                          color: _getPainLevelIconColor(painLevel is int ? painLevel : int.tryParse(painLevel.toString()) ?? 0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pain: $painLevel/10',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (note['nurse'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF199A8E).withOpacity(0.1),
                          child: Text(
                            nurseName.isNotEmpty ? nurseName[0].toUpperCase() : 'N',
                            style: const TextStyle(
                              color: Color(0xFF199A8E),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nurseName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Visiting Nurse',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF199A8E).withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        color: Color(0xFF199A8E),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tap to view complete details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF199A8E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (note['created_at'] != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Recorded',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTimeAgo(DateTime.tryParse(note['created_at']) ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _viewFullNoteDetail(int noteId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF199A8E),
        ),
      ),
    );

    try {
      final response = await _contactPersonService.getProgressNoteById(noteId);

      if (mounted) {
        Navigator.pop(context);
        _showDetailedNoteBottomSheet(response.data);
      }
    } catch (e) {
      debugPrint('[ContactPersonProgressNotes] API call failed: $e');
      debugPrint('[ContactPersonProgressNotes] Falling back to list data...');

      // Fallback: use data from the already loaded list
      if (mounted) {
        Navigator.pop(context);

        // Find the note in the loaded list
        final noteData = _progressNotes.firstWhere(
          (note) => note['id'] == noteId,
          orElse: () => <String, dynamic>{},
        );

        if (noteData.isNotEmpty) {
          // Debug: Log what data we have
          debugPrint('[ContactPersonProgressNotes] Note data keys: ${noteData.keys.toList()}');
          debugPrint('[ContactPersonProgressNotes] Has interventions: ${noteData['interventions']}');
          debugPrint('[ContactPersonProgressNotes] Has woundStatus: ${noteData['wound_status']}');
          debugPrint('[ContactPersonProgressNotes] Has otherObservations: ${noteData['other_observations']}');
          debugPrint('[ContactPersonProgressNotes] Has educationProvided: ${noteData['education_provided']}');
          debugPrint('[ContactPersonProgressNotes] Has familyConcerns: ${noteData['family_concerns']}');
          debugPrint('[ContactPersonProgressNotes] Has nextSteps: ${noteData['next_steps']}');

          // Convert the map data to ProgressNoteDetail
          final noteDetail = ProgressNoteDetail.fromJson(noteData);
          _showDetailedNoteBottomSheet(noteDetail);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load note details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDetailedNoteBottomSheet(ProgressNoteDetail noteDetail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF199A8E).withOpacity(0.1),
                    const Color(0xFF199A8E).withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF199A8E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.note_alt_rounded,
                          color: Color(0xFF199A8E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Daily Progress Note',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visit Date & Time
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF2196F3),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit Date & Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(DateTime.parse(noteDetail.visitDate))} • ${noteDetail.visitTime}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nurse Info
                    if (noteDetail.nurse != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF199A8E).withOpacity(0.1),
                              const Color(0xFF199A8E).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF199A8E).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF199A8E).withOpacity(0.2),
                                    const Color(0xFF199A8E).withOpacity(0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  noteDetail.nurse!.name.isNotEmpty
                                      ? noteDetail.nurse!.name[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF199A8E),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nurse',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    noteDetail.nurse!.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // General Condition & Pain Level
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.health_and_safety,
                                      size: 16,
                                      color: Color(0xFF199A8E),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'General Condition',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  noteDetail.generalCondition,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sentiment_satisfied_alt,
                                      size: 16,
                                      color: Color(0xFFFF9A00),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pain Level',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${noteDetail.painLevel}/10',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vitals
                    if (noteDetail.vitals != null && noteDetail.vitals!.isNotEmpty) ...[
                      _buildSectionHeader('Vital Signs', Icons.favorite),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF9A00).withOpacity(0.2),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (noteDetail.vitals!['temperature'] != null)
                              _buildVitalBadge(Icons.thermostat, 'Temp', '${noteDetail.vitals!['temperature']}°C', const Color(0xFFFF9A00)),
                            if (noteDetail.vitals!['pulse'] != null)
                              _buildVitalBadge(Icons.monitor_heart, 'Pulse', '${noteDetail.vitals!['pulse']} bpm', const Color(0xFFFF4757)),
                            if (noteDetail.vitals!['blood_pressure'] != null)
                              _buildVitalBadge(Icons.favorite, 'BP', noteDetail.vitals!['blood_pressure'].toString(), const Color(0xFFFF6B9D)),
                            if (noteDetail.vitals!['respiration'] != null)
                              _buildVitalBadge(Icons.air, 'Resp', '${noteDetail.vitals!['respiration']}/min', const Color(0xFF2196F3)),
                            if (noteDetail.vitals!['spo2'] != null)
                              _buildVitalBadge(Icons.speed, 'SpO₂', '${noteDetail.vitals!['spo2']}%', const Color(0xFF199A8E)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Interventions
                    if (noteDetail.interventions != null && _hasAnyInterventions(noteDetail.interventions!)) ...[
                      _buildSectionHeader('Interventions Provided', Icons.medical_services),
                      const SizedBox(height: 12),
                      ..._buildInterventionsList(noteDetail.interventions!),
                      const SizedBox(height: 20),
                    ],

                    // Wound Status
                    if (noteDetail.woundStatus != null && noteDetail.woundStatus!.isNotEmpty) ...[
                      _buildInfoSection(
                        Icons.healing,
                        'WOUND STATUS',
                        noteDetail.woundStatus!,
                        const Color(0xFFFFF3E0),
                        const Color(0xFFFF9800),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Other Observations
                    if (noteDetail.otherObservations != null && noteDetail.otherObservations!.isNotEmpty) ...[
                      _buildInfoSection(
                        Icons.remove_red_eye,
                        'OTHER OBSERVATIONS',
                        noteDetail.otherObservations!,
                        const Color(0xFFF5F0FF),
                        const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Education Provided
                    if (noteDetail.educationProvided != null && noteDetail.educationProvided!.isNotEmpty) ...[
                      _buildInfoSection(
                        Icons.school,
                        'EDUCATION PROVIDED',
                        noteDetail.educationProvided!,
                        const Color(0xFFE8F5E9),
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Family Concerns
                    if (noteDetail.familyConcerns != null && noteDetail.familyConcerns!.isNotEmpty) ...[
                      _buildInfoSection(
                        Icons.people,
                        'FAMILY/CLIENT CONCERNS',
                        noteDetail.familyConcerns!,
                        const Color(0xFFFFF8E1),
                        const Color(0xFFFFC107),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Next Steps
                    if (noteDetail.nextSteps != null && noteDetail.nextSteps!.isNotEmpty) ...[
                      _buildInfoSection(
                        Icons.event_note,
                        'PLAN / NEXT STEPS',
                        noteDetail.nextSteps!,
                        const Color(0xFFE3F2FD),
                        const Color(0xFF2196F3),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer with timestamp
            if (noteDetail.createdAt != null)
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Recorded',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimeAgo(DateTime.parse(noteDetail.createdAt!)),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalBadge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasAnyInterventions(Map<String, dynamic> interventions) {
    return interventions['medication_administered'] == true ||
        interventions['wound_care'] == true ||
        interventions['physiotherapy'] == true ||
        interventions['nutrition_support'] == true ||
        interventions['hygiene_care'] == true ||
        interventions['counseling'] == true ||
        interventions['other_interventions'] == true;
  }

  List<Widget> _buildInterventionsList(Map<String, dynamic> interventions) {
    final List<Widget> widgets = [];

    final types = [
      {'key': 'medication_administered', 'detailKey': 'medication_details', 'icon': Icons.medication, 'label': 'Medication Administered', 'color': const Color(0xFFFF4757)},
      {'key': 'wound_care', 'detailKey': 'wound_care_details', 'icon': Icons.healing, 'label': 'Wound Care', 'color': const Color(0xFFFF9800)},
      {'key': 'physiotherapy', 'detailKey': 'physiotherapy_details', 'icon': Icons.fitness_center, 'label': 'Physiotherapy/Exercise', 'color': const Color(0xFF2196F3)},
      {'key': 'nutrition_support', 'detailKey': 'nutrition_details', 'icon': Icons.restaurant, 'label': 'Nutrition/Feeding Support', 'color': const Color(0xFFFF9A00)},
      {'key': 'hygiene_care', 'detailKey': 'hygiene_details', 'icon': Icons.cleaning_services, 'label': 'Hygiene/Personal Care', 'color': const Color(0xFF6C63FF)},
      {'key': 'counseling', 'detailKey': 'counseling_details', 'icon': Icons.psychology, 'label': 'Counseling/Education', 'color': const Color(0xFF199A8E)},
      {'key': 'other_interventions', 'detailKey': 'other_details', 'icon': Icons.more_horiz, 'label': 'Other Interventions', 'color': const Color(0xFF9C27B0)},
    ];

    for (var type in types) {
      if (interventions[type['key']] == true) {
        final details = interventions[type['detailKey']] as String?;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (type['color'] as Color).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (type['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type['icon'] as IconData,
                      color: type['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['label'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (details != null && details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            details,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildInfoSection(IconData icon, String title, String content, Color backgroundColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF999999),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _getConditionIconColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'stable':
        return const Color(0xFF199A8E);
      case 'improved':
      case 'improving':
        return Colors.green;
      case 'deteriorating':
      case 'declining':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPainLevelIconColor(int painLevel) {
    if (painLevel == 0) return Colors.green;
    if (painLevel <= 3) return const Color(0xFF199A8E);
    if (painLevel <= 6) return const Color(0xFFFF9A00);
    return const Color(0xFFFF4757);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0, end: 1),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF199A8E).withOpacity(0.1),
                      const Color(0xFF199A8E).withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF199A8E).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF199A8E).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.note_alt_outlined,
                        size: 50,
                        color: Color(0xFF199A8E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF199A8E),
                  Color(0xFF147D73),
                ],
              ).createShader(bounds),
              child: const Text(
                'No Progress Notes Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Progress notes will appear here once they are added to the patient\'s care record',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadProgressNotes(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
