// lib/models/survey/survey_models.dart

/// Nurse info in survey context
class SurveyNurse {
  final int id;
  final String name;
  final String? avatar;

  SurveyNurse({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory SurveyNurse.fromJson(Map<String, dynamic> json) {
    return SurveyNurse(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'],
    );
  }
}

/// Schedule info in survey context
class SurveySchedule {
  final int id;
  final String date;
  final String time;

  SurveySchedule({
    required this.id,
    required this.date,
    required this.time,
  });

  factory SurveySchedule.fromJson(Map<String, dynamic> json) {
    return SurveySchedule(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
    );
  }
}

/// Pending survey item
class PendingSurvey {
  final int id;
  final String surveyTitle;
  final String surveyDescription;
  final int questionsCount;
  final SurveyNurse? nurse;
  final SurveySchedule? schedule;
  final DateTime? sentAt;
  final DateTime? expiresAt;

  PendingSurvey({
    required this.id,
    required this.surveyTitle,
    required this.surveyDescription,
    required this.questionsCount,
    this.nurse,
    this.schedule,
    this.sentAt,
    this.expiresAt,
  });

  factory PendingSurvey.fromJson(Map<String, dynamic> json) {
    return PendingSurvey(
      id: json['id'] ?? 0,
      surveyTitle: json['survey_title'] ?? '',
      surveyDescription: json['survey_description'] ?? '',
      questionsCount: json['questions_count'] ?? 0,
      nurse: json['nurse'] != null ? SurveyNurse.fromJson(json['nurse']) : null,
      schedule: json['schedule'] != null ? SurveySchedule.fromJson(json['schedule']) : null,
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get expiresInText {
    if (expiresAt == null) return '';
    final now = DateTime.now();
    final diff = expiresAt!.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Expires in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours > 0) return 'Expires in ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
    return 'Expires soon';
  }
}

/// Question choice for multiple choice questions
class QuestionChoice {
  final String value;
  final String label;

  QuestionChoice({
    required this.value,
    required this.label,
  });

  factory QuestionChoice.fromJson(Map<String, dynamic> json) {
    final label = json['label'] ?? '';
    // Use label as fallback if value is empty to ensure unique selection
    final value = (json['value'] != null && json['value'].toString().isNotEmpty)
        ? json['value'].toString()
        : label;
    return QuestionChoice(
      value: value,
      label: label,
    );
  }
}

/// Question options (for multiple choice)
class QuestionOptions {
  final List<QuestionChoice> choices;

  QuestionOptions({required this.choices});

  factory QuestionOptions.fromJson(Map<String, dynamic> json) {
    final choicesList = (json['choices'] as List?)
            ?.map((c) => QuestionChoice.fromJson(c))
            .toList() ??
        [];
    return QuestionOptions(choices: choicesList);
  }
}

/// Survey question types
enum SurveyQuestionType {
  rating,
  yesNo,
  text,
  multipleChoice,
}

/// Survey question
class SurveyQuestion {
  final int id;
  final String questionText;
  final String questionType;
  final bool isRequired;
  final QuestionOptions? options;

  SurveyQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.isRequired,
    this.options,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? 'text',
      isRequired: json['is_required'] ?? false,
      options: json['options'] != null
          ? QuestionOptions.fromJson(json['options'])
          : null,
    );
  }

  SurveyQuestionType get type {
    switch (questionType) {
      case 'rating':
        return SurveyQuestionType.rating;
      case 'yes_no':
        return SurveyQuestionType.yesNo;
      case 'multiple_choice':
        return SurveyQuestionType.multipleChoice;
      case 'text':
      default:
        return SurveyQuestionType.text;
    }
  }
}

/// Survey details with questions
class SurveyDetails {
  final int id;
  final String surveyTitle;
  final String surveyDescription;
  final SurveyNurse? nurse;
  final List<SurveyQuestion> questions;

  SurveyDetails({
    required this.id,
    required this.surveyTitle,
    required this.surveyDescription,
    this.nurse,
    required this.questions,
  });

  factory SurveyDetails.fromJson(Map<String, dynamic> json) {
    final questionsList = (json['questions'] as List?)
            ?.map((q) => SurveyQuestion.fromJson(q))
            .toList() ??
        [];
    return SurveyDetails(
      id: json['id'] ?? 0,
      surveyTitle: json['survey_title'] ?? '',
      surveyDescription: json['survey_description'] ?? '',
      nurse: json['nurse'] != null ? SurveyNurse.fromJson(json['nurse']) : null,
      questions: questionsList,
    );
  }
}

/// Survey answer for submission
class SurveyAnswer {
  final int questionId;
  final dynamic answer; // int (rating), bool (yes_no), String (text), List<String> (multiple_choice)

  SurveyAnswer({
    required this.questionId,
    required this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'answer': answer,
    };
  }
}

/// Completed survey item
class CompletedSurvey {
  final int id;
  final String surveyTitle;
  final SurveyNurse? nurse;
  final double? averageRating;
  final String completedAt;

  CompletedSurvey({
    required this.id,
    required this.surveyTitle,
    this.nurse,
    this.averageRating,
    required this.completedAt,
  });

  factory CompletedSurvey.fromJson(Map<String, dynamic> json) {
    return CompletedSurvey(
      id: json['id'] ?? 0,
      surveyTitle: json['survey_title'] ?? '',
      nurse: json['nurse'] != null ? SurveyNurse.fromJson(json['nurse']) : null,
      averageRating: _parseDouble(json['average_rating']),
      completedAt: json['completed_at'] ?? '',
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Response wrapper for pending surveys
class PendingSurveysResponse {
  final bool success;
  final List<PendingSurvey> surveys;
  final int total;
  final String? message;

  PendingSurveysResponse({
    required this.success,
    required this.surveys,
    required this.total,
    this.message,
  });

  factory PendingSurveysResponse.fromJson(Map<String, dynamic> json) {
    final surveysList = (json['data'] as List?)
            ?.map((s) => PendingSurvey.fromJson(s))
            .toList() ??
        [];
    return PendingSurveysResponse(
      success: json['success'] ?? false,
      surveys: surveysList,
      total: json['total'] ?? surveysList.length,
      message: json['message'],
    );
  }
}

/// Response wrapper for survey details
class SurveyDetailsResponse {
  final bool success;
  final SurveyDetails? details;
  final String? message;

  SurveyDetailsResponse({
    required this.success,
    this.details,
    this.message,
  });

  factory SurveyDetailsResponse.fromJson(Map<String, dynamic> json) {
    return SurveyDetailsResponse(
      success: json['success'] ?? false,
      details: json['data'] != null ? SurveyDetails.fromJson(json['data']) : null,
      message: json['message'],
    );
  }
}

/// Response wrapper for survey submission
class SurveySubmitResponse {
  final bool success;
  final String? message;
  final int? id;
  final String? completedAt;

  SurveySubmitResponse({
    required this.success,
    this.message,
    this.id,
    this.completedAt,
  });

  factory SurveySubmitResponse.fromJson(Map<String, dynamic> json) {
    return SurveySubmitResponse(
      success: json['success'] ?? false,
      message: json['message'],
      id: json['data']?['id'],
      completedAt: json['data']?['completed_at'],
    );
  }
}

/// Response wrapper for completed surveys
class CompletedSurveysResponse {
  final bool success;
  final List<CompletedSurvey> surveys;
  final String? message;

  CompletedSurveysResponse({
    required this.success,
    required this.surveys,
    this.message,
  });

  factory CompletedSurveysResponse.fromJson(Map<String, dynamic> json) {
    final surveysList = (json['data'] as List?)
            ?.map((s) => CompletedSurvey.fromJson(s))
            .toList() ??
        [];
    return CompletedSurveysResponse(
      success: json['success'] ?? false,
      surveys: surveysList,
      message: json['message'],
    );
  }
}
