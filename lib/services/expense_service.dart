import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/expense/expense_models.dart';

class ExpenseService {
  final ApiClient _apiClient = ApiClient();

  /// Get patient expenses (paginated).
  ///
  /// For contact persons, pass [patientId].
  Future<ExpenseListResponse> getExpenses({
    int? patientId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      String endpoint;
      if (patientId != null) {
        endpoint = ApiConfig.contactPersonExpensesEndpoint(patientId);
      } else {
        endpoint = ApiConfig.patientExpensesEndpoint;
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      });

      final response = await _apiClient.get(
        uri.toString(),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return ExpenseListResponse.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch expenses');
      }
    } catch (e) {
      debugPrint('ExpenseService.getExpenses error: $e');
      rethrow;
    }
  }

  /// Get a single expense detail.
  Future<ExpenseDetailResponse> getExpenseDetail({
    required int expenseId,
    int? patientId,
  }) async {
    try {
      String endpoint;
      if (patientId != null) {
        endpoint = ApiConfig.contactPersonExpenseDetailEndpoint(patientId, expenseId);
      } else {
        endpoint = ApiConfig.patientExpenseDetailEndpoint(expenseId);
      }

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return ExpenseDetailResponse.fromJson(response);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch expense detail');
      }
    } catch (e) {
      debugPrint('ExpenseService.getExpenseDetail error: $e');
      rethrow;
    }
  }

  /// Build the receipt download endpoint for [FileDownloadService].
  String getReceiptEndpoint({
    required int expenseId,
    int? patientId,
  }) {
    if (patientId != null) {
      return ApiConfig.contactPersonExpenseReceiptEndpoint(patientId, expenseId);
    }
    return ApiConfig.patientExpenseReceiptEndpoint(expenseId);
  }
}
