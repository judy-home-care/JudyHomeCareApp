import 'package:flutter/foundation.dart';
import '../../models/patients_assessments/progress_note_models.dart';
import '../../models/patients_assessments/medical_assessment_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

/// Custom exception for progress note operations
class ProgressNoteException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ProgressNoteException(this.message, {this.errors});

  @override
  String toString() => message;
}

class ProgressNoteService {
  static final ProgressNoteService _instance = ProgressNoteService._internal();
  factory ProgressNoteService() => _instance;
  ProgressNoteService._internal();

  final _apiClient = ApiClient();

  /// Create a progress note for a patient
  Future<CreateProgressNoteResponse> createProgressNote(
    int patientId,
    CreateProgressNoteRequest request,
  ) async {
    try {
      debugPrint('📝 Creating progress note for patient: $patientId');
      
      final requestBody = {
        'patient_id': patientId,
        ...request.toJson(),
      };
      
      debugPrint('📤 Request endpoint: ${ApiConfig.progressNotesEndpoint}');
      debugPrint('📤 Request body: $requestBody');

      final response = await _apiClient.post(
        ApiConfig.progressNotesEndpoint,
        body: requestBody,
        requiresAuth: true,
      );

      debugPrint('📥 Response received: $response');
      debugPrint('📥 Response type: ${response.runtimeType}');

      final progressNoteResponse = CreateProgressNoteResponse.fromJson(response);
      
      debugPrint('✅ Response parsed successfully');
      debugPrint('✅ Success: ${progressNoteResponse.success}');
      debugPrint('✅ Message: ${progressNoteResponse.message}');

      if (!progressNoteResponse.success) {
        debugPrint('❌ API returned success: false');
        debugPrint('❌ Errors: ${progressNoteResponse.errors}');
        throw ProgressNoteException(
          progressNoteResponse.message,
          errors: progressNoteResponse.errors,
        );
      }

      return progressNoteResponse;
    } on ApiError catch (e) {
      debugPrint('❌ ApiError caught in createProgressNote');
      debugPrint('❌ Status Code: ${e.statusCode}');
      debugPrint('❌ Display Message: ${e.displayMessage}');
      debugPrint('❌ Errors: ${e.errors}');
      throw ProgressNoteException(
        e.displayMessage,
        errors: e.errors,
      );
    } on ProgressNoteException catch (e) {
      debugPrint('❌ ProgressNoteException caught: ${e.message}');
      debugPrint('❌ Errors: ${e.errors}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in createProgressNote: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      throw ProgressNoteException(
        'An unexpected error occurred. Please try again.',
      );
    }
  }


  /// Update an existing progress note (Nurse only, within 24 hours)
/// 
/// Parameters:
/// - [noteId]: The ID of the progress note to update
/// - [request]: The updated progress note data
Future<CreateProgressNoteResponse> updateProgressNote(
  int noteId,
  CreateProgressNoteRequest request,
) async {
  try {
    debugPrint('📡 Updating progress note...');
    debugPrint('🔗 Note ID: $noteId');
    debugPrint('📋 Request data: ${request.toJson()}');
    
    final response = await _apiClient.put(
      ApiConfig.updateProgressNoteEndpoint(noteId),
      body: request.toJson(),
      requiresAuth: true,
    );

    debugPrint('✅ Update response received');
    debugPrint('📦 Response: $response');
    debugPrint('🎯 Success: ${response['success']}');

    if (response['success'] == true) {
      debugPrint('✅ Progress note updated successfully');
      return CreateProgressNoteResponse.fromJson(response);
    } else {
      debugPrint('❌ Update API returned success=false');
      debugPrint('❌ Error message: ${response['message']}');
      debugPrint('❌ Errors: ${response['errors']}');
      throw ProgressNoteException(
        response['message'] ?? 'Failed to update progress note',
        errors: response['errors'],
      );
    }
  } on ApiError catch (e) {
    debugPrint('❌ ApiError caught in updateProgressNote');
    debugPrint('❌ Status Code: ${e.statusCode}');
    debugPrint('❌ Display Message: ${e.displayMessage}');
    throw ProgressNoteException(
      e.displayMessage,
      errors: e.errors,
    );
  } on ProgressNoteException {
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('❌ Unexpected error in updateProgressNote: $e');
    debugPrint('❌ Stack trace: $stackTrace');
    throw ProgressNoteException(
      'An unexpected error occurred. Please try again.',
    );
  }
}

/// Check if a progress note is editable
/// 
/// Parameters:
/// - [noteId]: The ID of the progress note to check
/// 
/// Returns a map with:
/// - editable: bool - Whether the note can be edited
/// - is_author: bool - Whether current user is the author
/// - hours_since_creation: double - Hours since note was created
/// - hours_remaining: double - Hours left to edit (if editable)
/// - reason: String? - Reason why note cannot be edited (if not editable)
Future<Map<String, dynamic>> checkNoteEditable(int noteId) async {
  try {
    debugPrint('📡 Checking if note is editable...');
    debugPrint('🔗 Note ID: $noteId');
    
    final response = await _apiClient.get(
      ApiConfig.checkProgressNoteEditableEndpoint(noteId),
      requiresAuth: true,
    );

    debugPrint('✅ Editable check response received');
    debugPrint('📦 Response: $response');

    if (response['success'] == true) {
      debugPrint('✅ Editable: ${response['editable']}');
      return {
        'editable': response['editable'] ?? false,
        'is_author': response['is_author'] ?? false,
        'hours_since_creation': (response['hours_since_creation'] ?? 0).toDouble(),
        'hours_remaining': (response['hours_remaining'] ?? 0).toDouble(),
        'reason': response['reason'],
      };
    } else {
      debugPrint('⚠️ Editable check returned success=false');
      return {
        'editable': false,
        'is_author': false,
        'hours_since_creation': 0.0,
        'hours_remaining': 0.0,
        'reason': response['message'] ?? 'Unable to check editability',
      };
    }
  } on ApiError catch (e) {
    debugPrint('❌ ApiError in checkNoteEditable: ${e.displayMessage}');
    return {
      'editable': false,
      'is_author': false,
      'hours_since_creation': 0.0,
      'hours_remaining': 0.0,
      'reason': e.displayMessage,
    };
  } catch (e) {
    debugPrint('💥 Unexpected error in checkNoteEditable: $e');
    return {
      'editable': false,
      'is_author': false,
      'hours_since_creation': 0.0,
      'hours_remaining': 0.0,
      'reason': 'Error checking editability',
    };
  }
}

  /// Get all progress notes
  Future<Map<String, dynamic>> getAllProgressNotes() async {
    try {
      debugPrint('📋 Fetching all progress notes');
      debugPrint('📤 Endpoint: ${ApiConfig.progressNotesEndpoint}');
      
      final response = await _apiClient.get(
        ApiConfig.progressNotesEndpoint,
        requiresAuth: true,
      );

      debugPrint('📥 Response received: ${response.toString().substring(0, response.toString().length > 200 ? 200 : response.toString().length)}...');
      return response;
    } on ApiError catch (e) {
      debugPrint('❌ ApiError in getAllProgressNotes: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
        'data': [],
      };
    } catch (e) {
      debugPrint('❌ Unexpected error in getAllProgressNotes: $e');
      return {
        'success': false,
        'message': 'Failed to fetch progress notes. Please try again.',
        'data': [],
      };
    }
  }

  /// Get progress notes for a specific patient
  Future<Map<String, dynamic>> getPatientProgressNotes(int patientId) async {
    try {
      final endpoint = '${ApiConfig.progressNotesEndpoint}?patient_id=$patientId';
      debugPrint('📋 Fetching progress notes for patient: $patientId');
      debugPrint('📤 Endpoint: $endpoint');
      
      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      debugPrint('📥 Response received with ${(response['data'] as List?)?.length ?? 0} notes');
      return response;
    } on ApiError catch (e) {
      debugPrint('❌ ApiError in getPatientProgressNotes: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
        'data': [],
      };
    } catch (e) {
      debugPrint('❌ Unexpected error in getPatientProgressNotes: $e');
      return {
        'success': false,
        'message': 'Failed to fetch progress notes. Please try again.',
        'data': [],
      };
    }
  }

  /// Get a specific progress note by ID
  Future<Map<String, dynamic>> getProgressNoteDetail(int noteId) async {
    try {
      final endpoint = ApiConfig.progressNoteDetailEndpoint(noteId);
      debugPrint('📄 Fetching progress note detail: $noteId');
      debugPrint('📤 Endpoint: $endpoint');
      
      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      debugPrint('📥 Response received for note: $noteId');
      return response;
    } on ApiError catch (e) {
      debugPrint('❌ ApiError in getProgressNoteDetail: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      debugPrint('❌ Unexpected error in getProgressNoteDetail: $e');
      return {
        'success': false,
        'message': 'Failed to fetch progress note. Please try again.',
      };
    }
  }

  /// Create a new medical assessment
  Future<MedicalAssessmentResponse> createMedicalAssessment(
    MedicalAssessmentRequest request,
  ) async {
    try {
      debugPrint('🏥 Creating medical assessment');
      debugPrint('📤 Request body: ${request.toJson()}');
      
      final response = await _apiClient.post(
        '/api/mobile/nurse/medical-assessments',
        body: request.toJson(),
        requiresAuth: true,
      );

      debugPrint('📥 Medical assessment response: $response');
      return MedicalAssessmentResponse.fromJson(response);
    } on ApiError catch (e) {
      debugPrint('❌ ApiError in createMedicalAssessment: ${e.displayMessage}');
      return MedicalAssessmentResponse(
        success: false,
        message: e.displayMessage,
        errors: e.errors,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error in createMedicalAssessment: $e');
      return MedicalAssessmentResponse(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Get nurse's assigned patients (for dropdown selection)
  Future<Map<String, dynamic>> getNursePatients({
    String? search,
    String? priority,
  }) async {
    try {
      debugPrint('👥 Fetching nurse patients');
      
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (priority != null && priority != 'all') {
        queryParams['priority'] = priority;
      }

      final queryString = queryParams.isNotEmpty
          ? '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')
          : '';

      final endpoint = '/api/mobile/nurse/patients$queryString';
      debugPrint('📤 Endpoint: $endpoint');

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      debugPrint('📥 Patients response: ${(response['data'] as List?)?.length ?? 0} patients found');
      return response;
    } on ApiError catch (e) {
      debugPrint('❌ ApiError in getNursePatients: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
        'data': [],
      };
    } catch (e) {
      debugPrint('❌ Unexpected error in getNursePatients: $e');
      return {
        'success': false,
        'message': 'Failed to fetch patients. Please try again.',
        'data': [],
      };
    }
  }

  /// Validate vitals before submission
  String? validateVitals(ProgressNoteVitals? vitals) {
    if (vitals == null) return null;

    if (vitals.temperature != null) {
      if (vitals.temperature! < 0 || vitals.temperature! > 50) {
        return 'Temperature must be between 0 and 50°C';
      }
    }

    if (vitals.pulse != null) {
      if (vitals.pulse! < 0 || vitals.pulse! > 300) {
        return 'Pulse must be between 0 and 300 bpm';
      }
    }

    if (vitals.respiration != null) {
      if (vitals.respiration! < 0 || vitals.respiration! > 100) {
        return 'Respiration rate must be between 0 and 100/min';
      }
    }

    if (vitals.spo2 != null) {
      if (vitals.spo2! < 0 || vitals.spo2! > 100) {
        return 'SpO₂ must be between 0 and 100%';
      }
    }

    return null;
  }

  /// Validate pain level
  String? validatePainLevel(int painLevel) {
    if (painLevel < 0 || painLevel > 10) {
      return 'Pain level must be between 0 and 10';
    }
    return null;
  }

  /// Format date for API (YYYY-MM-DD)
  String formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format time for API (HH:mm)
  String formatTimeForApi(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}