import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/progress_notes/progress_note_models.dart';

/// Service for handling Progress Notes API calls
class ProgressNotesService {
  final ApiClient _apiClient = ApiClient();

  /// Get all progress notes with optional filters
  /// 
  /// Parameters:
  /// - [page]: Page number for pagination (default: 1)
  /// - [perPage]: Number of items per page (default: 15)
  /// - [search]: Search query for observations and notes
  /// - [startDate]: Filter notes from this date (yyyy-MM-dd)
  /// - [endDate]: Filter notes until this date (yyyy-MM-dd)
  /// - [patientId]: Filter by specific patient (for nurses)
  Future<ProgressNotesResponse> getProgressNotes({
    int page = 1,
    int perPage = 15,
    String? search,
    String? startDate,
    String? endDate,
    int? patientId,
    String? sortOrder, // ✅ Add this parameter
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      if (patientId != null) {
        queryParams['patient_id'] = patientId.toString();
      }

      // ✅ Add sort order parameter
      if (sortOrder != null && sortOrder.isNotEmpty) {
        queryParams['sort_order'] = sortOrder;
      }

      final uri = Uri.parse(ApiConfig.progressNotesEndpoint).replace(
        queryParameters: queryParams,
      );

      print('📡 [ProgressNotesService] Fetching progress notes...');
      print('🔗 [ProgressNotesService] URL: ${uri.toString()}');
      
      final response = await _apiClient.get(uri.toString());

      if (response['success'] == true) {
        return ProgressNotesResponse.fromJson(response);
      } else {
        throw ProgressNotesException(
          message: response['message'] ?? 'Failed to fetch progress notes',
        );
      }
    } catch (e) {
      if (e is ProgressNotesException) {
        rethrow;
      }
      throw ProgressNotesException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Get a specific progress note by ID
  /// 
  /// Parameters:
  /// - [noteId]: The ID of the progress note to fetch
  Future<ProgressNoteDetailResponse> getProgressNoteById(int noteId) async {
    try {
      print('📡 [ProgressNotesService] Fetching progress note detail...');
      print('🔗 [ProgressNotesService] Note ID: $noteId');
      print('🔗 [ProgressNotesService] Endpoint: ${ApiConfig.progressNoteDetailEndpoint(noteId)}');
      
      final response = await _apiClient.get(
        ApiConfig.progressNoteDetailEndpoint(noteId),
      );

      print('✅ [ProgressNotesService] Detail response received');
      print('📦 [ProgressNotesService] Response type: ${response.runtimeType}');
      print('🎯 [ProgressNotesService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [ProgressNotesService] Parsing detail response');
        return ProgressNoteDetailResponse.fromJson(response);
      } else {
        print('❌ [ProgressNotesService] Detail API returned success=false');
        print('❌ [ProgressNotesService] Error message: ${response['message']}');
        throw ProgressNotesException(
          message: response['message'] ?? 'Failed to fetch progress note',
        );
      }
    } catch (e) {
      print('💥 [ProgressNotesService] Detail exception caught: $e');
      print('💥 [ProgressNotesService] Exception type: ${e.runtimeType}');
      
      if (e is ProgressNotesException) {
        rethrow;
      }
      throw ProgressNotesException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Create a new progress note (Nurse only)
  /// 
  /// Parameters:
  /// - [request]: The progress note data to create
  Future<CreateProgressNoteResponse> createProgressNote(
    CreateProgressNoteRequest request,
  ) async {
    try {
      print('📡 [ProgressNotesService] Creating progress note...');
      print('📋 [ProgressNotesService] Request data: ${request.toJson()}');
      
      final response = await _apiClient.post(
        ApiConfig.progressNotesEndpoint,
        body: request.toJson(),
        requiresAuth: true,
      );

      print('✅ [ProgressNotesService] Create response received');
      print('📦 [ProgressNotesService] Response: $response');
      print('🎯 [ProgressNotesService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [ProgressNotesService] Progress note created successfully');
        return CreateProgressNoteResponse.fromJson(response);
      } else {
        print('❌ [ProgressNotesService] Create API returned success=false');
        print('❌ [ProgressNotesService] Error message: ${response['message']}');
        print('❌ [ProgressNotesService] Errors: ${response['errors']}');
        throw ProgressNotesException(
          message: response['message'] ?? 'Failed to create progress note',
          errors: response['errors'],
        );
      }
    } catch (e) {
      print('💥 [ProgressNotesService] Create exception caught: $e');
      print('💥 [ProgressNotesService] Exception type: ${e.runtimeType}');
      
      if (e is ProgressNotesException) {
        rethrow;
      }
      throw ProgressNotesException(
        message: 'An unexpected error occurred: $e',
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
      print('📡 [ProgressNotesService] Updating progress note...');
      print('🔗 [ProgressNotesService] Note ID: $noteId');
      print('📋 [ProgressNotesService] Request data: ${request.toJson()}');
      
      final response = await _apiClient.put(
        ApiConfig.updateProgressNoteEndpoint(noteId),
        body: request.toJson(),
        requiresAuth: true,
      );

      print('✅ [ProgressNotesService] Update response received');
      print('📦 [ProgressNotesService] Response: $response');
      print('🎯 [ProgressNotesService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [ProgressNotesService] Progress note updated successfully');
        return CreateProgressNoteResponse.fromJson(response);
      } else {
        print('❌ [ProgressNotesService] Update API returned success=false');
        print('❌ [ProgressNotesService] Error message: ${response['message']}');
        print('❌ [ProgressNotesService] Errors: ${response['errors']}');
        throw ProgressNotesException(
          message: response['message'] ?? 'Failed to update progress note',
          errors: response['errors'],
        );
      }
    } catch (e) {
      print('💥 [ProgressNotesService] Update exception caught: $e');
      print('💥 [ProgressNotesService] Exception type: ${e.runtimeType}');
      
      if (e is ProgressNotesException) {
        rethrow;
      }
      throw ProgressNotesException(
        message: 'An unexpected error occurred: $e',
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
      print('📡 [ProgressNotesService] Checking if note is editable...');
      print('🔗 [ProgressNotesService] Note ID: $noteId');
      
      final response = await _apiClient.get(
        ApiConfig.checkProgressNoteEditableEndpoint(noteId),
        requiresAuth: true,
      );

      print('✅ [ProgressNotesService] Editable check response received');
      print('📦 [ProgressNotesService] Response: $response');

      if (response['success'] == true) {
        print('✅ [ProgressNotesService] Editable: ${response['editable']}');
        return {
          'editable': response['editable'] ?? false,
          'is_author': response['is_author'] ?? false,
          'hours_since_creation': response['hours_since_creation'] ?? 0.0,
          'hours_remaining': response['hours_remaining'] ?? 0.0,
          'reason': response['reason'],
        };
      } else {
        print('⚠️ [ProgressNotesService] Editable check returned success=false');
        return {
          'editable': false,
          'is_author': false,
          'hours_since_creation': 0.0,
          'hours_remaining': 0.0,
          'reason': response['message'] ?? 'Unable to check editability',
        };
      }
    } catch (e) {
      print('💥 [ProgressNotesService] Editable check exception: $e');
      return {
        'editable': false,
        'is_author': false,
        'hours_since_creation': 0.0,
        'hours_remaining': 0.0,
        'reason': 'Error checking editability: $e',
      };
    }
  }

  /// Search progress notes with a query
  /// 
  /// This is a convenience method that calls getProgressNotes with search parameter
  Future<ProgressNotesResponse> searchProgressNotes({
    required String query,
    int page = 1,
    int perPage = 15,
  }) async {
    print('🔍 [ProgressNotesService] Searching progress notes with query: "$query"');
    return getProgressNotes(
      search: query,
      page: page,
      perPage: perPage,
    );
  }

  /// Filter progress notes by date range
  /// 
  /// This is a convenience method that calls getProgressNotes with date filters
  Future<ProgressNotesResponse> filterProgressNotesByDateRange({
    required String startDate,
    required String endDate,
    int page = 1,
    int perPage = 15,
  }) async {
    print('📅 [ProgressNotesService] Filtering by date range: $startDate to $endDate');
    return getProgressNotes(
      startDate: startDate,
      endDate: endDate,
      page: page,
      perPage: perPage,
    );
  }
}

// ============================================================================
// EXCEPTION CLASS
// ============================================================================

/// Custom exception for Progress Notes operations
class ProgressNotesException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ProgressNotesException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;
}