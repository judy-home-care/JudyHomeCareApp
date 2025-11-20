import '../../models/transport/transport_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import 'package:flutter/foundation.dart'; 

// Transport List Response Model
class TransportListResponse {
  final bool success;
  final String? message;
  final List<TransportRequest> data;
  final int total;
  final int currentPage;
  final int lastPage;
  final int? perPage;
  final Map<String, int>? counts;

  TransportListResponse({
    required this.success,
    this.message,
    required this.data,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    this.perPage,
    this.counts,
  });

  factory TransportListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final requests = dataList
        .map((item) => TransportRequest.fromJson(item as Map<String, dynamic>))
        .toList();

    Map<String, int>? counts;
    if (json['counts'] != null) {
      final countsData = json['counts'] as Map<String, dynamic>;
      counts = countsData.map((key, value) => MapEntry(key, value as int));
    }

    return TransportListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: requests,
      total: json['total'] as int? ?? 0,
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int?,
      counts: counts,
    );
  }
}

class TransportService {
  static final TransportService _instance = TransportService._internal();
  factory TransportService() => _instance;
  TransportService._internal();

  final _apiClient = ApiClient();

  /// Get all transport requests for nurse with pagination
  Future<TransportListResponse> getTransportRequests({
    int page = 1,
    int perPage = 15,
    String? status,
    String? priority,
    String? type,
    String? search,
  }) async {
    try {
      debugPrint('🚚 Fetching transport requests...');
      debugPrint('🔎 Filters => page: $page, status: $status, priority: $priority, type: $type, search: $search');

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      if (priority != null && priority != 'all') {
        queryParams['priority'] = priority;
      }
      if (type != null && type != 'all') {
        queryParams['type'] = type;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = '${ApiConfig.transportRequestsEndpoint}?$queryString';

      debugPrint('🌐 Final endpoint: $endpoint');

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      debugPrint('✅ API Response received');
      debugPrint('📊 Total: ${response['total']}, Page: ${response['current_page']}/${response['last_page']}');

      return TransportListResponse.fromJson(response);

    } on ApiError catch (e) {
      debugPrint('❌ API Error: ${e.displayMessage}');
      return TransportListResponse(
        success: false,
        message: e.displayMessage,
        data: [],
        total: 0,
        currentPage: page,
        lastPage: 1,
      );
    } catch (e, stack) {
      debugPrint('💥 Unexpected error: $e');
      debugPrint('🧩 Stack trace: $stack');
      return TransportListResponse(
        success: false,
        message: 'An unexpected error occurred. Please try again.',
        data: [],
        total: 0,
        currentPage: page,
        lastPage: 1,
      );
    }
  }

  /// Get a specific transport request
  Future<Map<String, dynamic>> getTransportRequest(int requestId) async {
    try {
      debugPrint('🚚 Fetching transport request with ID: $requestId');

      final response = await _apiClient.get(
        ApiConfig.transportRequestDetailEndpoint(requestId),
        requiresAuth: true,
      );

      debugPrint('✅ API Response: $response');

      if (response['success'] == true && response['data'] != null) {
        final request = TransportRequest.fromJson(
          response['data'] as Map<String, dynamic>,
        );

        debugPrint('📦 Parsed TransportRequest: $request');

        return {
          'success': true,
          'request': request,
        };
      }

      debugPrint('⚠️ Failed to fetch transport request: ${response['message']}');
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch transport request',
      };
    } on ApiError catch (e) {
      debugPrint('❌ API Error: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e, stack) {
      debugPrint('💥 Unexpected error: $e');
      debugPrint('🧩 Stack trace: $stack');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Create a new transport request
  Future<Map<String, dynamic>> createTransportRequest(
    CreateTransportRequest request,
  ) async {
    try {
      debugPrint('🚀 Sending transport request: ${request.toJson()}');

      final response = await _apiClient.post(
        ApiConfig.createTransportRequestEndpoint,
        body: request.toJson(),
        requiresAuth: true,
      );

      debugPrint('✅ API Response: $response');

      if (response['success'] == true && response['data'] != null) {
        return {
          'success': true,
          'message': response['message'] ?? 'Transport request created successfully',
          'data': response['data'],
        };
      }

      debugPrint('⚠️ Transport request failed: ${response['message']}');
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to create transport request',
      };
    } on ApiError catch (e) {
      debugPrint('❌ API Error: ${e.displayMessage}, details: ${e.errors}');
      return {
        'success': false,
        'message': e.displayMessage,
        'errors': e.errors,
      };
    } catch (e, stack) {
      debugPrint('💥 Unexpected error: $e');
      debugPrint('🧩 Stack trace: $stack');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Get available drivers
  Future<Map<String, dynamic>> getAvailableDrivers({
    String transportType = 'regular',
  }) async {
    try {
      debugPrint('🚗 Fetching available drivers...');
      debugPrint('🛞 Transport type: $transportType');

      final endpoint = '${ApiConfig.availableDriversEndpoint}?transport_type=$transportType';
      debugPrint('🌐 Endpoint: $endpoint');

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      debugPrint('✅ API Response: $response');

      if (response['success'] == true) {
        final data = response['data'] as List;
        final drivers = data
            .map((json) => Driver.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('👨‍✈️ Parsed ${drivers.length} available drivers');

        return {
          'success': true,
          'drivers': drivers,
          'total': response['total'] ?? drivers.length,
        };
      }

      debugPrint('⚠️ Failed to fetch available drivers: ${response['message']}');
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch available drivers',
      };
    } on ApiError catch (e) {
      debugPrint('❌ API Error: ${e.displayMessage}');
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e, stack) {
      debugPrint('💥 Unexpected error: $e');
      debugPrint('🧩 Stack trace: $stack');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }
}