import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/feedback/patient_feedback_service.dart';
import '../../models/feedback/feedback_models.dart';

class PatientFeedbackScreen extends StatefulWidget {
  const PatientFeedbackScreen({Key? key}) : super(key: key);

  @override
  State<PatientFeedbackScreen> createState() => _PatientFeedbackScreenState();
}

class _PatientFeedbackScreenState extends State<PatientFeedbackScreen> {
  final _feedbackService = PatientFeedbackService();
  
  List<NurseForFeedback> _nurses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNurses();
  }

  Future<void> _loadNurses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _feedbackService.getNursesForFeedback();
      
      if (response['success'] == true) {
        setState(() {
          _nurses = (response['nurses'] as List)
              .map((json) => NurseForFeedback.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load nurses';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Provide Feedback',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _nurses.isEmpty
                  ? _buildEmptyState()
                  : _buildNursesList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          const Text('Loading nurses...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'An error occurred'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadNurses,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildEmptyState() {
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
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
                    AppColors.primaryGreen.withOpacity(0.1),
                    AppColors.primaryGreen.withOpacity(0.05),
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
                        color: AppColors.primaryGreen.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.feedback_outlined,
                      size: 50,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AppColors.primaryGreen,
                AppColors.primaryGreen.withOpacity(0.7),
              ],
            ).createShader(bounds),
            child: const Text(
              'No Nurses to Review',
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
              'You can provide feedback after a nurse completes a visit with you',
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

  Widget _buildNursesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _nurses.length,
      itemBuilder: (context, index) {
        return _buildNurseCard(_nurses[index]);
      },
    );
  }

Widget _buildNurseCard(NurseForFeedback nurse) {
  final hasFeedback = nurse.hasGeneralFeedback;
  final hasUnreviewedSchedules = nurse.recentSchedules.any((s) => !s.hasFeedback);
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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
        onTap: () => _showScheduleSelectionDialog(nurse),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGreen.withOpacity(0.2),
                          AppColors.primaryGreen.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primaryGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nurse.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasUnreviewedSchedules 
                              ? 'Tap to rate recent visits' 
                              : hasFeedback 
                                  ? 'All visits reviewed' 
                                  : 'Tap to provide feedback',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (nurse.completedSchedules > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${nurse.completedSchedules} completed visit${nurse.completedSchedules != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (hasUnreviewedSchedules) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB648).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${nurse.recentSchedules.where((s) => !s.hasFeedback).length} unreviewed',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFFB648),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    hasUnreviewedSchedules ? Icons.rate_review : Icons.check_circle,
                    color: hasUnreviewedSchedules 
                        ? const Color(0xFFFFB648)
                        : AppColors.primaryGreen,
                    size: 24,
                  ),
                ],
              ),
              // Show recent schedules if any
              if (nurse.recentSchedules.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Visits',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...nurse.recentSchedules.take(3).map((schedule) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                schedule.hasFeedback 
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 14,
                                color: schedule.hasFeedback
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${schedule.date} - ${schedule.time}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

void _showScheduleSelectionDialog(NurseForFeedback nurse) {
  final unreviewedSchedules = nurse.recentSchedules.where((s) => !s.hasFeedback).toList();
  
  // If no unreviewed schedules, show option for general feedback
  if (unreviewedSchedules.isEmpty) {
    _showFeedbackDialog(nurse, scheduleId: null);
    return;
  }
  
  // Show schedule selection dialog
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Visit to Review',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            nurse.name,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ...unreviewedSchedules.map((schedule) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showFeedbackDialog(
                      nurse,
                      scheduleId: schedule.id,
                      scheduleDate: schedule.date,
                      scheduleTime: schedule.time,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.date,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                schedule.time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (schedule.location != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  schedule.location!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFeedbackDialog(nurse, scheduleId: null);
            },
            child: const Text('Leave general feedback instead'),
          ),
        ],
      ),
    ),
  );
}

    void _showFeedbackDialog(
    NurseForFeedback nurse, {
    int? scheduleId,
    String? scheduleDate,
    String? scheduleTime,
    }) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FeedbackDialog(
        nurseId: nurse.id,
        nurseName: nurse.name,
        scheduleId: scheduleId,
        scheduleDate: scheduleDate,
        scheduleTime: scheduleTime,
        existingRating: scheduleId == null ? nurse.existingRating : null,
        onSubmitted: () {
            _loadNurses();
        },
        ),
    );
    }
}

class FeedbackDialog extends StatefulWidget {
  final int nurseId;
  final String nurseName;
  final int? scheduleId;
  final String? scheduleDate;
  final String? scheduleTime;
  final int? existingRating;
  final VoidCallback onSubmitted;

  const FeedbackDialog({
    Key? key,
    required this.nurseId,
    required this.nurseName,
    this.scheduleId,
    this.scheduleDate,
    this.scheduleTime,
    this.existingRating,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _feedbackService = PatientFeedbackService();
  final _feedbackController = TextEditingController();
  
  int _rating = 0;
  bool _wouldRecommend = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 0;
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    if (_feedbackController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 10 characters of feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _feedbackService.submitFeedback(
        nurseId: widget.nurseId,
        scheduleId: widget.scheduleId,
        rating: _rating,
        feedbackText: _feedbackController.text.trim(),
        wouldRecommend: _wouldRecommend,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pop(context);
        widget.onSubmitted();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Feedback submitted successfully!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to submit feedback'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Add icon to show if it's schedule-specific
                      if (widget.scheduleId != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.scheduleId != null
                                  ? 'Rate Visit'
                                  : 'Rate ${widget.nurseName}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.scheduleId != null
                                  ? '${widget.scheduleDate ?? ""} ${widget.scheduleTime != null ? "• ${widget.scheduleTime}" : ""}'
                                  : 'General feedback for ${widget.nurseName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How would you rate your experience?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                index < _rating ? Icons.star : Icons.star_border,
                                color: const Color(0xFFFFB648),
                                size: 40,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Share your feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 5,
                      maxLength: 1000,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                      },
                      decoration: InputDecoration(
                        hintText: 'Tell us about your experience...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Would you recommend this nurse?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Switch(
                            value: _wouldRecommend,
                            onChanged: (value) {
                              setState(() {
                                _wouldRecommend = value;
                              });
                            },
                            activeColor: AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}