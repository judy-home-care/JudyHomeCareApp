import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'secure_storage.dart';
import '../services/app_version_service.dart';

/// Custom API Error exception class
class ApiError implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  final int statusCode;

  ApiError({
    required this.message,
    this.errors,
    required this.statusCode,
  });

  /// Get display message for UI
  String get displayMessage {
    if (errors != null && errors!.isNotEmpty) {
      // If there are validation errors, return the first one
      final firstError = errors!.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }
    return message;
  }

  /// Check if error is a validation error
  bool get isValidationError => errors != null && errors!.isNotEmpty;

  /// Check if error is a network error
  bool get isNetworkError => statusCode == 0;

  /// Check if error is an auth error (401)
  bool get isAuthError => statusCode == 401;

  /// Check if error is a server error (5xx)
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  @override
  String toString() => 'ApiError: $message (Status: $statusCode)';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  ApiClient._internal() {
    // Initialize the HTTP client immediately
    _client = http.Client();
  }

  final _storage = SecureStorage();
  late http.Client _client;

  // Re-initialize client if needed (optional)
  void initialize() {
    _client = http.Client();
  }

  // Dispose client
  void dispose() {
    _client.close();
  }

  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final requestHeaders = await _buildHeaders(headers, requiresAuth);

      final response = await _client
          .get(url, headers: requestHeaders)
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final requestHeaders = await _buildHeaders(headers, requiresAuth);

      final response = await _client
          .post(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final requestHeaders = await _buildHeaders(headers, requiresAuth);

      final response = await _client
          .put(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final requestHeaders = await _buildHeaders(headers, requiresAuth);

      final response = await _client
          .delete(url, headers: requestHeaders)
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Build headers with auth token if required
  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
    bool requiresAuth,
  ) async {
    final headers = Map<String, String>.from(ApiConfig.headers);

    // Add version headers for backend version checking
    final versionService = AppVersionService();
    headers.addAll(versionService.getVersionHeaders());

    if (requiresAuth) {
      final token = await _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  // Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success response
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Error response
      Map<String, dynamic> errorBody;
      try {
        errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        errorBody = {
          'message': 'Server error: ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }

      throw ApiError(
        message: errorBody['message'] as String? ?? 'Request failed',
        errors: errorBody['errors'] as Map<String, dynamic>?,
        statusCode: response.statusCode,
      );
    }
  }

  // Handle errors
  ApiError _handleError(dynamic error) {
    if (error is ApiError) {
      return error;
    } else if (error is SocketException) {
      return ApiError(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } else if (error is http.ClientException) {
      return ApiError(
        message: 'Connection failed. Please try again.',
        statusCode: 0,
      );
    } else if (error is FormatException) {
      return ApiError(
        message: 'Invalid response format from server.',
        statusCode: 0,
      );
    } else {
      return ApiError(
        message: 'An unexpected error occurred: ${error.toString()}',
        statusCode: 0,
      );
    }
  }
}