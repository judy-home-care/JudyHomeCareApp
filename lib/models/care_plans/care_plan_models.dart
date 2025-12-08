// Care Plan Entry Model
class CarePlanEntry {
  final int? id;
  final int? carePlanId;
  final String? carePlanTitle;
  final String? type; // 'intervention' or 'evaluation'
  final String? typeLabel;
  final String? entryDate;
  final String? entryDateFormatted;
  final String? entryTime;
  final String? entryTimeFormatted;
  final String? notes;
  final String? nursingDiagnosis;
  final String? goalsExpectedOutcomes;
  final String? nursingOrders;
  final String? rationales;
  final CarePlanEntryNurse? nurse;
  final String? createdAt;

  CarePlanEntry({
    this.id,
    this.carePlanId,
    this.carePlanTitle,
    this.type,
    this.typeLabel,
    this.entryDate,
    this.entryDateFormatted,
    this.entryTime,
    this.entryTimeFormatted,
    this.notes,
    this.nursingDiagnosis,
    this.goalsExpectedOutcomes,
    this.nursingOrders,
    this.rationales,
    this.nurse,
    this.createdAt,
  });

  factory CarePlanEntry.fromJson(Map<String, dynamic> json) {
    return CarePlanEntry(
      id: json['id'] as int?,
      carePlanId: json['care_plan_id'] as int?,
      carePlanTitle: json['care_plan_title'] as String?,
      type: json['type'] as String?,
      typeLabel: json['type_label'] as String?,
      entryDate: json['entry_date'] as String?,
      entryDateFormatted: json['entry_date_formatted'] as String?,
      entryTime: json['entry_time'] as String?,
      entryTimeFormatted: json['entry_time_formatted'] as String?,
      notes: json['notes'] as String?,
      nursingDiagnosis: json['nursing_diagnosis'] as String?,
      goalsExpectedOutcomes: json['goals_expected_outcomes'] as String?,
      nursingOrders: json['nursing_orders'] as String?,
      rationales: json['rationales'] as String?,
      nurse: json['nurse'] != null
          ? CarePlanEntryNurse.fromJson(json['nurse'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'notes': notes,
    };
    if (id != null) map['id'] = id;
    if (carePlanId != null) map['care_plan_id'] = carePlanId;
    if (nursingDiagnosis != null) map['nursing_diagnosis'] = nursingDiagnosis;
    if (goalsExpectedOutcomes != null) map['goals_expected_outcomes'] = goalsExpectedOutcomes;
    if (nursingOrders != null) map['nursing_orders'] = nursingOrders;
    if (rationales != null) map['rationales'] = rationales;
    return map;
  }

  /// Check if this is an intervention entry
  bool get isIntervention => type == 'intervention';

  /// Check if this is an evaluation entry
  bool get isEvaluation => type == 'evaluation';

  /// Check if any of the 4 column fields have content
  bool get hasColumnContent =>
      (nursingDiagnosis != null && nursingDiagnosis!.isNotEmpty) ||
      (goalsExpectedOutcomes != null && goalsExpectedOutcomes!.isNotEmpty) ||
      (nursingOrders != null && nursingOrders!.isNotEmpty) ||
      (rationales != null && rationales!.isNotEmpty);
}

// Nurse info for care plan entry
class CarePlanEntryNurse {
  final int id;
  final String name;

  CarePlanEntryNurse({
    required this.id,
    required this.name,
  });

  factory CarePlanEntryNurse.fromJson(Map<String, dynamic> json) {
    return CarePlanEntryNurse(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Nurse',
    );
  }
}

// Create Care Plan Entry Request Model
class CreateCarePlanEntryRequest {
  final String? nurseInterventions;
  final String? evaluation;

  CreateCarePlanEntryRequest({
    this.nurseInterventions,
    this.evaluation,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (nurseInterventions != null) map['nurse_interventions'] = nurseInterventions;
    if (evaluation != null) map['evaluation'] = evaluation;
    return map;
  }
}

// Care Plan Exception
class CarePlanException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  final int statusCode;

  CarePlanException({
    required this.message,
    this.errors,
    required this.statusCode,
  });

  @override
  String toString() => 'CarePlanException: $message (Status: $statusCode)';
}

// Care Plan Model
class CarePlan {
  final int id;
  final String patient;
  final int? patientId;
  final String carePlan;
  final String description;
  final String doctor;
  final int? doctorId;
  final int? careRequestId;
  final String doctorSpecialty;
  final String primaryNurse;
  final String nurseExperience;
  final String careType;
  final String status;
  final String priority;
  final String frequency;
  final int estimatedHours;
  double progress; 
  final String? startDate;
  final String? endDate;
  final List<dynamic> medications;
  final List<dynamic> specialInstructions;
  final List<String> careTasks;
  List<int> completedTasks;
  final List<CarePlanEntry> carePlanEntries;

  CarePlan({
    required this.id,
    required this.patient,
    this.patientId,
    required this.carePlan,
    required this.description,
    required this.doctor,
    this.doctorId,
    this.careRequestId,
    required this.doctorSpecialty,
    required this.primaryNurse,
    required this.nurseExperience,
    required this.careType,
    required this.status,
    required this.priority,
    required this.frequency,
    required this.estimatedHours,
    required this.progress,
    this.startDate,
    this.endDate,
    required this.medications,
    required this.specialInstructions,
    required this.careTasks,
    List<int>? completedTasks,
    List<CarePlanEntry>? carePlanEntries,
  }) : completedTasks = completedTasks ?? [],
       carePlanEntries = carePlanEntries ?? [];

  /// Parse care_tasks from JSON - handles both 'care_tasks' and 'care_plan_entries' as strings
  static List<String> _parseCareTasks(Map<String, dynamic> json) {
    // First try care_tasks
    final careTasks = json['care_tasks'] as List<dynamic>?;
    if (careTasks != null && careTasks.isNotEmpty) {
      return careTasks.map((e) => e.toString()).toList();
    }

    // Fall back to care_plan_entries if they are strings
    final entries = json['care_plan_entries'] as List<dynamic>?;
    if (entries != null && entries.isNotEmpty) {
      // Check if entries are strings (simple task descriptions)
      if (entries.first is String) {
        return entries.map((e) => e.toString()).toList();
      }
    }

    return [];
  }

  /// Parse care_plan_entries from JSON - handles both Map objects and strings
  static List<CarePlanEntry> _parseCarePlanEntries(Map<String, dynamic> json) {
    final entries = json['care_plan_entries'] as List<dynamic>?;
    if (entries == null || entries.isEmpty) {
      return [];
    }

    // Check if entries are Map objects (full CarePlanEntry objects)
    if (entries.first is Map<String, dynamic>) {
      return entries
          .map((e) => CarePlanEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // If entries are strings, they're simple task descriptions - return empty list
    // (the strings will be handled by _parseCareTasks)
    return [];
  }

  factory CarePlan.fromJson(Map<String, dynamic> json) {
    try {
      // Handle nurse - can be a string or an object with 'name' field
      String primaryNurse = 'Unassigned';
      String nurseExperience = '';
      final nurseData = json['nurse'] ?? json['primary_nurse'];
      if (nurseData is String) {
        primaryNurse = nurseData;
      } else if (nurseData is Map<String, dynamic>) {
        primaryNurse = nurseData['name'] as String? ?? 'Unassigned';
        nurseExperience = nurseData['experience'] as String? ?? '';
      } else if (json['primary_nurse'] is String) {
        primaryNurse = json['primary_nurse'] as String;
      }

      // Handle doctor - can be a string or an object with 'name' field
      String doctor = 'Not Assigned';
      String doctorSpecialty = '';
      final doctorData = json['doctor'];
      if (doctorData is String) {
        doctor = doctorData;
      } else if (doctorData is Map<String, dynamic>) {
        doctor = doctorData['name'] as String? ?? 'Not Assigned';
        doctorSpecialty = doctorData['specialty'] as String? ?? '';
      } else if (doctorData == null) {
        doctor = 'Not Assigned';
      }

      // Handle title/care_plan field - API might return 'title' or 'care_plan'
      String carePlanTitle = json['title'] as String? ??
                             json['care_plan'] as String? ??
                             'Untitled Care Plan';

      return CarePlan(
        // Required fields with safe casting and defaults
        id: json['id'] as int? ?? 0,
        patient: json['patient'] as String? ?? 'Unknown Patient',
        patientId: json['patient_id'] as int?,
        carePlan: carePlanTitle,
        description: json['description'] as String? ?? '',
        doctor: doctor,
        doctorId: json['doctor_id'] as int?,
        careRequestId: json['care_request_id'] as int?,
        doctorSpecialty: json['doctor_specialty'] as String? ?? doctorSpecialty,
        primaryNurse: primaryNurse,
        nurseExperience: json['nurse_experience'] as String? ?? nurseExperience,
        careType: json['care_type'] as String? ?? 'General Care',
        status: json['status'] as String? ?? 'Active',
        priority: json['priority'] as String? ?? 'Medium',
        frequency: json['frequency'] as String? ?? 'Daily',
        estimatedHours: json['estimated_hours'] as int? ?? 8,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        medications: json['medications'] as List<dynamic>? ?? [],
        specialInstructions: json['special_instructions'] as List<dynamic>? ?? [],
        careTasks: _parseCareTasks(json),
        completedTasks: (json['completed_tasks'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
        carePlanEntries: _parseCarePlanEntries(json),
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing CarePlan from JSON: $e');
      print('📦 Raw JSON: $json');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient': patient,
        'patient_id': patientId,
        'care_plan': carePlan,
        'description': description,
        'doctor': doctor,
        'doctor_id': doctorId,
        'care_request_id': careRequestId,
        'doctor_specialty': doctorSpecialty,
        'primary_nurse': primaryNurse,
        'nurse_experience': nurseExperience,
        'care_type': careType,
        'status': status,
        'priority': priority,
        'frequency': frequency,
        'estimated_hours': estimatedHours,
        'progress': progress,
        'start_date': startDate,
        'end_date': endDate,
        'medications': medications,
        'special_instructions': specialInstructions,
        'care_tasks': careTasks,
        'completed_tasks': completedTasks,
        'care_plan_entries': carePlanEntries.map((e) => e.toJson()).toList(),
      };

  String get patientInitials {
    final names = patient.split(' ');
    if (names.isEmpty || patient == 'Unknown Patient') {
      return 'UP';
    }
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0].isNotEmpty
        ? names[0].substring(0, 1).toUpperCase()
        : 'U';
  }

  /// Helper method to get completion percentage
  int get completionPercentage => (progress * 100).toInt();

  /// Helper method to check if a task is completed
  bool isTaskCompleted(int index) => completedTasks.contains(index);

  /// Helper method to get number of completed tasks
  int get completedTaskCount => completedTasks.length;

  /// Helper method to get total number of tasks
  int get totalTaskCount => careTasks.length;
}

// Care Plans Response Model with Pagination Support
class CarePlansResponse {
  final bool success;
  final String message;
  final List<CarePlan> data;
  
  // Pagination fields
  final int? total;
  final int? currentPage;
  final int? lastPage;
  final int? perPage;
  final int? from;
  final int? to;

  CarePlansResponse({
    required this.success,
    required this.message,
    required this.data,
    this.total,
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.from,
    this.to,
  });

  factory CarePlansResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both direct array response and paginated response
      List<CarePlan> carePlans = [];
      int? total;
      int? currentPage;
      int? lastPage;
      int? perPage;
      int? from;
      int? to;

      // Check if response has pagination metadata
      if (json.containsKey('meta') || json.containsKey('current_page')) {
        // Laravel-style pagination
        final meta = json['meta'] as Map<String, dynamic>?;
        
        if (meta != null) {
          total = meta['total'] as int?;
          currentPage = meta['current_page'] as int?;
          lastPage = meta['last_page'] as int?;
          perPage = meta['per_page'] as int?;
          from = meta['from'] as int?;
          to = meta['to'] as int?;
        } else {
          // Pagination fields directly in response
          total = json['total'] as int?;
          currentPage = json['current_page'] as int?;
          lastPage = json['last_page'] as int?;
          perPage = json['per_page'] as int?;
          from = json['from'] as int?;
          to = json['to'] as int?;
        }

        // Data might be nested in 'data' key
        final dataKey = json['data'];
        if (dataKey is List) {
          carePlans = (dataKey as List<dynamic>)
              .map((e) => CarePlan.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } else if (json['data'] is List) {
        // Non-paginated response with data array
        carePlans = (json['data'] as List<dynamic>)
            .map((e) => CarePlan.fromJson(e as Map<String, dynamic>))
            .toList();
        total = carePlans.length;
        currentPage = 1;
        lastPage = 1;
      }

      return CarePlansResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data: carePlans,
        total: total,
        currentPage: currentPage,
        lastPage: lastPage,
        perPage: perPage,
        from: from,
        to: to,
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing CarePlansResponse: $e');
      print('📦 Raw JSON: $json');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final json = {
      'success': success,
      'message': message,
      'data': data.map((e) => e.toJson()).toList(),
    };

    // Add pagination fields if they exist
    if (total != null) json['total'] = total!;
    if (currentPage != null) json['current_page'] = currentPage!;
    if (lastPage != null) json['last_page'] = lastPage!;
    if (perPage != null) json['per_page'] = perPage!;
    if (from != null) json['from'] = from!;
    if (to != null) json['to'] = to!;

    return json;
  }

  /// Check if there are more pages to load
  bool get hasMorePages {
    if (currentPage == null || lastPage == null) return false;
    return currentPage! < lastPage!;
  }

  /// Check if this is the first page
  bool get isFirstPage => currentPage == 1 || currentPage == null;

  /// Check if this is the last page
  bool get isLastPage {
    if (currentPage == null || lastPage == null) return true;
    return currentPage! >= lastPage!;
  }

  /// Get the next page number
  int? get nextPage {
    if (hasMorePages && currentPage != null) {
      return currentPage! + 1;
    }
    return null;
  }

  /// Get the previous page number
  int? get previousPage {
    if (currentPage != null && currentPage! > 1) {
      return currentPage! - 1;
    }
    return null;
  }
}

// Create Care Plan Request Model
class CreateCarePlanRequest {
  final int patientId;
  final int? doctorId;
  final int? careRequestId;
  final String title;
  final String description;
  final String careType;
  final String priority;
  final String startDate;
  final String? endDate;
  final String frequency;
  final List<String> careTasks;

  CreateCarePlanRequest({
    required this.patientId,
    this.doctorId,
    this.careRequestId, 
    required this.title,
    required this.description,
    required this.careType,
    required this.priority,
    required this.startDate,
    this.endDate,
    required this.frequency,
    required this.careTasks,
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        if (doctorId != null) 'doctor_id': doctorId,
        if (careRequestId != null) 'care_request_id': careRequestId,
        'title': title,
        'description': description,
        'care_type': careType,
        'priority': priority,
        'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'frequency': frequency,
        'care_plan_entries': careTasks,
      };
}

// Update Care Plan Request Model
class UpdateCarePlanRequest {
  final int? patientId;
  final int? doctorId;
  final String? title;
  final String? description;
  final String? careType;
  final String? priority;
  final String? startDate;
  final String? endDate;
  final String? frequency;
  final String? status;
  final List<String>? careTasks;

  UpdateCarePlanRequest({
    this.patientId,
    this.doctorId,
    this.title,
    this.description,
    this.careType,
    this.priority,
    this.startDate,
    this.endDate,
    this.frequency,
    this.status,
    this.careTasks,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    
    if (patientId != null) json['patient_id'] = patientId;
    if (doctorId != null) json['doctor_id'] = doctorId;
    if (title != null) json['title'] = title;
    if (description != null) json['description'] = description;
    if (careType != null) json['care_type'] = careType;
    if (priority != null) json['priority'] = priority;
    if (startDate != null) json['start_date'] = startDate;
    if (endDate != null) json['end_date'] = endDate;
    if (frequency != null) json['frequency'] = frequency;
    if (status != null) json['status'] = status;
    if (careTasks != null) json['care_tasks'] = careTasks;
    
    return json;
  }
}

// Toggle Task Completion Request Model
class ToggleTaskRequest {
  final int taskIndex;
  final bool isCompleted;

  ToggleTaskRequest({
    required this.taskIndex,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
        'task_index': taskIndex,
        'is_completed': isCompleted,
      };
}

// Single Care Plan Response Model
class SingleCarePlanResponse {
  final bool success;
  final String message;
  final CarePlan data;

  SingleCarePlanResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory SingleCarePlanResponse.fromJson(Map<String, dynamic> json) {
    try {
      return SingleCarePlanResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data: CarePlan.fromJson(json['data'] as Map<String, dynamic>),
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing SingleCarePlanResponse: $e');
      print('📦 Raw JSON: $json');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        'data': data.toJson(),
      };
}