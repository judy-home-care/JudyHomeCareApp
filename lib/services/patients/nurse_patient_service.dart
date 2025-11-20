import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/patients/nurse_patient_models.dart';

class NursePatientService {
  static final NursePatientService _instance = NursePatientService._internal();
  factory NursePatientService() => _instance;
  NursePatientService._internal();

  final _apiClient = ApiClient();

  /// Get all patients assigned to the authenticated nurse with pagination support
  Future<NursePatientsResponse> getNursePatients({
    String? search,
    String? priority,
    int? page,
    int? perPage,
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
      String endpoint = ApiConfig.nursePatientsEndpoint;
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
  Future<PatientDetailResponse> getPatientDetail(int patientId) async {
    try {
      final endpoint = ApiConfig.nursePatientDetailEndpoint(patientId);

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