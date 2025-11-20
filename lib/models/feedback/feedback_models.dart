class NurseForFeedback {
  final int id;
  final String name;
  final String? phone;
  final bool hasGeneralFeedback;
  final int? existingRating;
  final int completedSchedules;
  final String? lastScheduleDate;
  final double? averageRating;
  final int totalFeedback;
  final List<RecentSchedule> recentSchedules;

  NurseForFeedback({
    required this.id,
    required this.name,
    this.phone,
    required this.hasGeneralFeedback,
    this.existingRating,
    required this.completedSchedules,
    this.lastScheduleDate,
    this.averageRating,
    required this.totalFeedback,
    required this.recentSchedules,
  });

  factory NurseForFeedback.fromJson(Map<String, dynamic> json) {
    return NurseForFeedback(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      hasGeneralFeedback: json['has_general_feedback'] ?? false,
      existingRating: json['existing_rating'],
      completedSchedules: json['completed_schedules'] ?? 0,
      lastScheduleDate: json['last_schedule_date'],
      averageRating: json['average_rating'] != null 
          ? (json['average_rating'] as num).toDouble()
          : null,
      totalFeedback: json['total_feedback'] ?? 0,
      recentSchedules: (json['recent_schedules'] as List?)
          ?.map((s) => RecentSchedule.fromJson(s))
          .toList() ?? [],
    );
  }
}

class RecentSchedule {
  final int id;
  final String date;
  final String time;
  final String? location;
  final bool hasFeedback;

  RecentSchedule({
    required this.id,
    required this.date,
    required this.time,
    this.location,
    required this.hasFeedback,
  });

  factory RecentSchedule.fromJson(Map<String, dynamic> json) {
    return RecentSchedule(
      id: json['id'],
      date: json['date'],
      time: json['time'],
      location: json['location'],
      hasFeedback: json['has_feedback'] ?? false,
    );
  }
}

class PatientFeedback {
  final int id;
  final int nurseId;
  final String nurseName;
  final int? scheduleId;
  final int rating;
  final String stars;
  final String feedbackText;
  final bool wouldRecommend;
  final String careDate;
  final String status;
  final bool isResponded;
  final String? responseText;
  final String? respondedAt;
  final int daysSinceSubmission;
  final String createdAt;

  PatientFeedback({
    required this.id,
    required this.nurseId,
    required this.nurseName,
    this.scheduleId,
    required this.rating,
    required this.stars,
    required this.feedbackText,
    required this.wouldRecommend,
    required this.careDate,
    required this.status,
    required this.isResponded,
    this.responseText,
    this.respondedAt,
    required this.daysSinceSubmission,
    required this.createdAt,
  });

  factory PatientFeedback.fromJson(Map<String, dynamic> json) {
    return PatientFeedback(
      id: json['id'],
      nurseId: json['nurse_id'],
      nurseName: json['nurse_name'],
      scheduleId: json['schedule_id'],
      rating: json['rating'],
      stars: json['stars'] ?? '',
      feedbackText: json['feedback_text'],
      wouldRecommend: json['would_recommend'] ?? false,
      careDate: json['care_date'],
      status: json['status'],
      isResponded: json['is_responded'] ?? false,
      responseText: json['response_text'],
      respondedAt: json['responded_at'],
      daysSinceSubmission: json['days_since_submission'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}

class FeedbackStatistics {
  final int totalFeedbackSubmitted;
  final double averageRatingGiven;
  final int nursesRated;
  final int wouldRecommendCount;
  final int pendingResponses;
  final int respondedFeedback;
  final Map<String, int> ratingDistribution;

  FeedbackStatistics({
    required this.totalFeedbackSubmitted,
    required this.averageRatingGiven,
    required this.nursesRated,
    required this.wouldRecommendCount,
    required this.pendingResponses,
    required this.respondedFeedback,
    required this.ratingDistribution,
  });

  factory FeedbackStatistics.fromJson(Map<String, dynamic> json) {
    return FeedbackStatistics(
      totalFeedbackSubmitted: json['total_feedback_submitted'] ?? 0,
      averageRatingGiven: (json['average_rating_given'] ?? 0).toDouble(),
      nursesRated: json['nurses_rated'] ?? 0,
      wouldRecommendCount: json['would_recommend_count'] ?? 0,
      pendingResponses: json['pending_responses'] ?? 0,
      respondedFeedback: json['responded_feedback'] ?? 0,
      ratingDistribution: Map<String, int>.from(json['rating_distribution'] ?? {}),
    );
  }
}