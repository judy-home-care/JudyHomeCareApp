import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/contact_person/contact_person_survey_service.dart';
import '../../models/survey/survey_models.dart';

class ContactPersonSurveySubmissionScreen extends StatefulWidget {
  final int patientId;
  final int surveyId;
  final String surveyTitle;

  const ContactPersonSurveySubmissionScreen({
    Key? key,
    required this.patientId,
    required this.surveyId,
    required this.surveyTitle,
  }) : super(key: key);

  @override
  State<ContactPersonSurveySubmissionScreen> createState() =>
      _ContactPersonSurveySubmissionScreenState();
}

class _ContactPersonSurveySubmissionScreenState
    extends State<ContactPersonSurveySubmissionScreen> {
  final _surveyService = ContactPersonSurveyService();
  final _pageController = PageController();

  SurveyDetails? _surveyDetails;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _currentPage = 0;

  final Map<int, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadSurveyDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSurveyDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _surveyService.getSurveyDetails(
      widget.patientId,
      widget.surveyId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success && response.details != null) {
          _surveyDetails = response.details;
        } else {
          _errorMessage = response.message ?? 'Failed to load survey';
        }
      });
    }
  }

  bool _isCurrentQuestionAnswered() {
    if (_surveyDetails == null) return false;
    final question = _surveyDetails!.questions[_currentPage];
    final answer = _answers[question.id];

    if (!question.isRequired) return true;

    switch (question.type) {
      case SurveyQuestionType.rating:
        return answer != null && answer > 0;
      case SurveyQuestionType.yesNo:
        return answer != null;
      case SurveyQuestionType.text:
        return answer != null && (answer as String).trim().isNotEmpty;
      case SurveyQuestionType.multipleChoice:
        return answer != null && (answer as List).isNotEmpty;
    }
  }

  bool _areAllRequiredQuestionsAnswered() {
    if (_surveyDetails == null) return false;

    for (final question in _surveyDetails!.questions) {
      if (!question.isRequired) continue;

      final answer = _answers[question.id];
      switch (question.type) {
        case SurveyQuestionType.rating:
          if (answer == null || answer <= 0) return false;
          break;
        case SurveyQuestionType.yesNo:
          if (answer == null) return false;
          break;
        case SurveyQuestionType.text:
          if (answer == null || (answer as String).trim().isEmpty) return false;
          break;
        case SurveyQuestionType.multipleChoice:
          if (answer == null || (answer as List).isEmpty) return false;
          break;
      }
    }
    return true;
  }

  void _goToNextQuestion() {
    if (!_isCurrentQuestionAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer this question before continuing'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentPage < _surveyDetails!.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousQuestion() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitSurvey() async {
    if (!_areAllRequiredQuestionsAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all required questions'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final answers = _surveyDetails!.questions.map((question) {
      return SurveyAnswer(
        questionId: question.id,
        answer: _answers[question.id],
      );
    }).toList();

    final response = await _surveyService.submitSurvey(
      patientId: widget.patientId,
      responseId: widget.surveyId,
      answers: answers,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response.success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Failed to submit survey'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGreen,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank You!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The survey has been submitted successfully on behalf of the patient. Thank you for your feedback!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => _showExitConfirmation(),
        ),
        title: Text(
          widget.surveyTitle,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildSurveyContent(),
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
          const Text('Loading survey...'),
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
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSurveyDetails,
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

  Widget _buildSurveyContent() {
    final totalQuestions = _surveyDetails!.questions.length;
    final isLastQuestion = _currentPage == totalQuestions - 1;

    return Column(
      children: [
        _buildProgressIndicator(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: totalQuestions,
            itemBuilder: (context, index) {
              return _buildQuestionPage(_surveyDetails!.questions[index], index);
            },
          ),
        ),
        _buildNavigationButtons(isLastQuestion),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final totalQuestions = _surveyDetails!.questions.length;
    final progress = ((_currentPage + 1) / totalQuestions);

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentPage + 1} of $totalQuestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(SurveyQuestion question, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getQuestionTypeLabel(question.type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    if (question.isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAnswerInput(question),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(SurveyQuestion question) {
    switch (question.type) {
      case SurveyQuestionType.rating:
        return _buildRatingInput(question);
      case SurveyQuestionType.yesNo:
        return _buildYesNoInput(question);
      case SurveyQuestionType.text:
        return _buildTextInput(question);
      case SurveyQuestionType.multipleChoice:
        return _buildMultipleChoiceInput(question);
    }
  }

  Widget _buildRatingInput(SurveyQuestion question) {
    final currentRating = _answers[question.id] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          const Text(
            'Tap a star to rate',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= currentRating;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _answers[question.id] = starValue;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFB648),
                    size: 48,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          if (currentRating > 0)
            Text(
              _getRatingLabel(currentRating),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYesNoInput(SurveyQuestion question) {
    final currentAnswer = _answers[question.id];

    return Row(
      children: [
        Expanded(
          child: _buildYesNoOption(
            question: question,
            value: true,
            label: 'Yes',
            icon: Icons.check_circle_outline,
            isSelected: currentAnswer == true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildYesNoOption(
            question: question,
            value: false,
            label: 'No',
            icon: Icons.cancel_outlined,
            isSelected: currentAnswer == false,
          ),
        ),
      ],
    );
  }

  Widget _buildYesNoOption({
    required SurveyQuestion question,
    required bool value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answers[question.id] = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? (value ? AppColors.primaryGreen : Colors.red).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (value ? AppColors.primaryGreen : Colors.red)
                : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected
                  ? (value ? AppColors.primaryGreen : Colors.red)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (value ? AppColors.primaryGreen : Colors.red)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(SurveyQuestion question) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: TextField(
        maxLines: 5,
        maxLength: 1000,
        onChanged: (value) {
          setState(() {
            _answers[question.id] = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Type your answer here...',
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
    );
  }

  Widget _buildMultipleChoiceInput(SurveyQuestion question) {
    final choices = question.options?.choices ?? [];
    final selectedChoices = (_answers[question.id] as List<String>?) ?? [];

    return Column(
      children: choices.map((choice) {
        final isSelected = selectedChoices.contains(choice.value);

        return GestureDetector(
          onTap: () {
            setState(() {
              final currentList = List<String>.from(selectedChoices);
              if (isSelected) {
                currentList.remove(choice.value);
              } else {
                currentList.add(choice.value);
              }
              _answers[question.id] = currentList;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    choice.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons(bool isLastQuestion) {
    return Container(
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
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _goToPreviousQuestion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (isLastQuestion ? _submitSurvey : _goToNextQuestion),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  : Text(
                      isLastQuestion ? 'Submit Survey' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getQuestionTypeLabel(SurveyQuestionType type) {
    switch (type) {
      case SurveyQuestionType.rating:
        return 'Rating';
      case SurveyQuestionType.yesNo:
        return 'Yes/No';
      case SurveyQuestionType.text:
        return 'Text';
      case SurveyQuestionType.multipleChoice:
        return 'Multiple Choice';
    }
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Exit Survey?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
