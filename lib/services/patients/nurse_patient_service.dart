import 'package:flutter/foundation.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/patients/nurse_patient_models.dart';

class NursePatientService {
  static final NursePatientService _instance = NursePatientService._internal();
  factory NursePatientService() => _instance;
  NursePatientService._internal();

  final _apiClient = ApiClient();

  /// Bumped every time a therapy note is created/updated so other screens
  /// (e.g. the therapist dashboard) can refresh their stats without the user
  /// pulling to refresh.
  static final ValueNotifier<int> therapyNotesChanged = ValueNotifier<int>(0);

  /// Get all patients assigned to the authenticated nurse with pagination support
  ///
  /// [apiPrefix] selects the role endpoint family: `ApiConfig.nursePrefix`
  /// (default) or `ApiConfig.therapistPrefix` for physiotherapists / speech
  /// therapists, who only see patients assigned to them on the portal.
  Future<NursePatientsResponse> getNursePatients({
    String? search,
    String? priority,
    int? page,
    int? perPage,
    String apiPrefix = ApiConfig.nursePrefix,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (priority != null && priority != 'All') {
        queryParams['priority'] = priority;
      }
      if (page != null) {
        queryParams['page'] = page.toString();
      }
      if (perPage != null) {
        queryParams['per_page'] = perPage.toString();
      }

      // Build endpoint with query parameters
      String endpoint = '$apiPrefix/patients';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint = '$endpoint?$queryString';
      }

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('success')) {
        throw NursePatientException(
          message: 'Response missing "success" field',
          statusCode: 0,
        );
      }

      if (!response.containsKey('data')) {
        throw NursePatientException(
          message: 'Response missing "data" field',
          statusCode: 0,
        );
      }

      return NursePatientsResponse.fromJson(response);

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'An unexpected error occurred. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Get detailed information about a specific patient
  Future<PatientDetailResponse> getPatientDetail(
    int patientId, {
    String apiPrefix = ApiConfig.nursePrefix,
  }) async {
    try {
      final endpoint = '$apiPrefix/patients/$patientId';

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('success')) {
        throw NursePatientException(
          message: 'Response missing "success" field',
          statusCode: 0,
        );
      }

      if (!response.containsKey('data')) {
        throw NursePatientException(
          message: 'Response missing "data" field',
          statusCode: 0,
        );
      }

      return PatientDetailResponse.fromJson(response);

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'An unexpected error occurred. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Get the vitals timeline for a patient — every reading recorded by any
  /// nurse on the care team, grouped by day and paginated by day.
  Future<VitalsTimelineResponse> getPatientVitals(
    int patientId, {
    int? page,
    int? perPage,
    String apiPrefix = ApiConfig.nursePrefix,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      var endpoint = '$apiPrefix/patients/$patientId/vitals';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint = '$endpoint?$queryString';
      }

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('data')) {
        throw NursePatientException(
          message: 'Response missing "data" field',
          statusCode: 0,
        );
      }

      return VitalsTimelineResponse.fromJson(response);

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to load vitals. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Create a new progress note for a patient
  Future<Map<String, dynamic>> createProgressNote({
    required int patientId,
    required Map<String, dynamic> noteData,
  }) async {
    try {
      // Use the correct endpoint without patientId in URL
      final endpoint = ApiConfig.progressNotesEndpoint;
      
      // Include patient_id in the request body
      final body = {
        'patient_id': patientId,
        ...noteData,
      };
      
      final response = await _apiClient.post(
        endpoint,
        body: body,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      return response;

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to save progress note. Please try again.',
        statusCode: 0,
      );
    }
  }


  /// Get progress notes for a specific patient
  /// Note: This endpoint needs to be added to ApiConfig if you want to fetch notes
  Future<List<ProgressNote>> getPatientProgressNotes(int patientId) async {
    try {
      // Use query parameter to filter by patient
      final endpoint = '${ApiConfig.progressNotesEndpoint}?patient_id=$patientId';

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('data')) {
        throw NursePatientException(
          message: 'Response missing "data" field',
          statusCode: 0,
        );
      }

      final data = response['data'] as List<dynamic>;
      return data.map((json) => ProgressNote.fromJson(json as Map<String, dynamic>)).toList();

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to load progress notes. Please try again.',
        statusCode: 0,
      );
    }
  }

  Future<List<ProgressNote>> getAllProgressNotes() async {
  try {
    final endpoint = ApiConfig.progressNotesEndpoint;

    final response = await _apiClient.get(
      endpoint,
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw NursePatientException(
        message: 'Invalid response type',
        statusCode: 0,
      );
    }

    if (!response.containsKey('data')) {
      throw NursePatientException(
        message: 'Response missing "data" field',
        statusCode: 0,
      );
    }

    final data = response['data'] as List<dynamic>;
    return data.map((json) => ProgressNote.fromJson(json as Map<String, dynamic>)).toList();

  } on ApiError catch (e) {
    throw NursePatientException(
      message: e.displayMessage,
      statusCode: e.statusCode,
    );
  } catch (e) {
    throw NursePatientException(
      message: 'Failed to load progress notes. Please try again.',
      statusCode: 0,
    );
  }
}

/// Get a specific progress note by ID
Future<ProgressNote> getProgressNoteDetail(int noteId) async {
  try {
    final endpoint = ApiConfig.progressNoteDetailEndpoint(noteId);

    final response = await _apiClient.get(
      endpoint,
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw NursePatientException(
        message: 'Invalid response type',
        statusCode: 0,
      );
    }

    if (!response.containsKey('data')) {
      throw NursePatientException(
        message: 'Response missing "data" field',
        statusCode: 0,
      );
    }

    return ProgressNote.fromJson(response['data'] as Map<String, dynamic>);

  } on ApiError catch (e) {
    throw NursePatientException(
      message: e.displayMessage,
      statusCode: e.statusCode,
    );
  } catch (e) {
    throw NursePatientException(
      message: 'Failed to load progress note. Please try again.',
      statusCode: 0,
    );
  }
}

  // ==========================================================================
  // THERAPY NOTES (Physiotherapist / Speech Therapist only)
  // ==========================================================================

  /// Fetch therapy session notes for a patient (both disciplines, newest first).
  Future<List<TherapyNote>> getTherapyNotes(
    int patientId, {
    String? type, // physiotherapy | speech_therapy
    bool mineOnly = false,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (mineOnly) 'mine': '1',
      };
      final query = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiClient.get(
        '${ApiConfig.therapistPatientTherapyNotesEndpoint(patientId)}?$query',
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic> || !response.containsKey('data')) {
        throw NursePatientException(
          message: 'Invalid response while loading therapy notes',
          statusCode: 0,
        );
      }

      final data = response['data'] as List<dynamic>;
      return data
          .whereType<Map>()
          .map((e) => TherapyNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiError catch (e) {
      throw NursePatientException(message: e.displayMessage, statusCode: e.statusCode);
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to load therapy notes. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Save a new therapy session note for a patient. The therapy type is
  /// derived server-side from the logged-in therapist's role.
  Future<TherapyNote> createTherapyNote({
    required int patientId,
    required String note,
    String? sessionDate, // yyyy-MM-dd (defaults to today on the server)
    String? sessionTime, // HH:mm
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.therapistPatientTherapyNotesEndpoint(patientId),
        body: {
          'note': note,
          if (sessionDate != null) 'session_date': sessionDate,
          if (sessionTime != null) 'session_time': sessionTime,
        },
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic> || response['data'] is! Map) {
        throw NursePatientException(
          message: response is Map && response['message'] != null
              ? response['message'].toString()
              : 'Invalid response while saving note',
          statusCode: 0,
        );
      }

      final created = TherapyNote.fromJson(Map<String, dynamic>.from(response['data']));
      therapyNotesChanged.value++;
      return created;
    } on ApiError catch (e) {
      // Surface validation messages (e.g. "Please enter your session notes.")
      String message = e.displayMessage;
      if (e.errors != null && e.errors!.isNotEmpty) {
        final parts = <String>[];
        e.errors!.forEach((key, value) {
          if (value is List) {
            parts.addAll(value.map((v) => v.toString()));
          } else {
            parts.add(value.toString());
          }
        });
        if (parts.isNotEmpty) message = parts.join('\n');
      }
      throw NursePatientException(message: message, statusCode: e.statusCode);
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to save note. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Update one of the therapist's own notes (within the 24h edit window).
  Future<TherapyNote> updateTherapyNote({
    required int noteId,
    required String note,
    String? sessionDate,
    String? sessionTime,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiConfig.therapistTherapyNoteEndpoint(noteId),
        body: {
          'note': note,
          if (sessionDate != null) 'session_date': sessionDate,
          if (sessionTime != null) 'session_time': sessionTime,
        },
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic> || response['data'] is! Map) {
        throw NursePatientException(
          message: 'Invalid response while updating note',
          statusCode: 0,
        );
      }

      final updated = TherapyNote.fromJson(Map<String, dynamic>.from(response['data']));
      therapyNotesChanged.value++;
      return updated;
    } on ApiError catch (e) {
      throw NursePatientException(message: e.displayMessage, statusCode: e.statusCode);
    } on NursePatientException {
      rethrow;
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to update note. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Toggle care task completion
  Future<Map<String, dynamic>> toggleCareTaskCompletion({
    required int carePlanId,
    required int taskIndex,
    required bool isCompleted,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.toggleCareTaskEndpoint(carePlanId),
        body: {
          'task_index': taskIndex,
          'is_completed': isCompleted,
        },
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw NursePatientException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      return response;

    } on ApiError catch (e) {
      throw NursePatientException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw NursePatientException(
        message: 'Failed to update task completion. Please try again.',
        statusCode: 0,
      );
    }
  }
}


/// Custom exception for nurse patient operations
class NursePatientException implements Exception {
  final String message;
  final int statusCode;

  NursePatientException({
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}