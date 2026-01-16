// lib/services/wallet_service.dart

import 'dart:developer';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/wallet/wallet_models.dart';

/// Service for handling Wallet API calls
class WalletService {
  final ApiClient _apiClient = ApiClient();

  // ==================== WALLET INFO ====================

  /// Get wallet information (balance, status)
  ///
  /// Parameters:
  /// - [patientId]: Optional patient ID (required for contact persons)
  ///
  /// Returns wallet info including balance and status
  Future<WalletInfoResponse> getWalletInfo({int? patientId}) async {
    try {
      log('📡 [WalletService] Fetching wallet info...');
      if (patientId != null) {
        log('👤 [WalletService] For patient ID: $patientId');
      }

      String endpoint = ApiConfig.walletInfoEndpoint;
      if (patientId != null) {
        endpoint = '$endpoint?patient_id=$patientId';
      }

      final response = await _apiClient.get(
        endpoint,
        requiresAuth: true,
      );

      log('✅ [WalletService] Wallet info response received');
      log('🎯 [WalletService] Success: ${response['success']}');

      if (response['success'] == true) {
        log('✅ [WalletService] Wallet info fetched successfully');
        log('💰 [WalletService] Balance: ${response['data']?['formatted_balance']}');
        return WalletInfoResponse.fromJson(response);
      } else {
        log('❌ [WalletService] Wallet info fetch failed');
        throw WalletException(
          message: response['message'] ?? 'Failed to fetch wallet info',
        );
      }
    } catch (e) {
      log('💥 [WalletService] Error fetching wallet info: $e');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to fetch wallet info',
      );
    }
  }

  // ==================== PAYMENT CONFIGURATION ====================

  /// Get payment configuration for wallet deposits
  ///
  /// Returns payment config including public key and available channels
  Future<WalletPaymentConfigResponse> getPaymentConfig() async {
    try {
      log('📡 [WalletService] Fetching payment configuration...');

      final response = await _apiClient.get(
        ApiConfig.walletPaymentConfigEndpoint,
        requiresAuth: true,
      );

      log('✅ [WalletService] Payment config response received');
      log('🎯 [WalletService] Success: ${response['success']}');

      if (response['success'] == true) {
        log('✅ [WalletService] Payment configuration fetched successfully');
        return WalletPaymentConfigResponse.fromJson(response);
      } else {
        log('❌ [WalletService] Payment config fetch failed');
        throw WalletException(
          message: response['message'] ?? 'Failed to fetch payment configuration',
        );
      }
    } catch (e) {
      log('💥 [WalletService] Error fetching payment config: $e');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to fetch payment configuration',
      );
    }
  }

  // ==================== DEPOSIT ====================

  /// Initiate a wallet deposit
  ///
  /// Parameters:
  /// - [amount]: Amount to deposit
  /// - [channel]: Payment channel (card, mobile_money, bank)
  /// - [provider]: Mobile money provider (if channel is mobile_money)
  /// - [phoneNumber]: Phone number (if channel is mobile_money)
  /// - [patientId]: Optional patient ID (required for contact persons)
  ///
  /// Returns deposit initialization data including authorization URL
  Future<DepositInitResponse> initiateDeposit({
    required double amount,
    required String channel,
    String? provider,
    String? phoneNumber,
    int? patientId,
  }) async {
    try {
      log('📡 [WalletService] Initiating deposit...');
      log('💰 [WalletService] Amount: $amount');
      log('📱 [WalletService] Channel: $channel');
      if (patientId != null) {
        log('👤 [WalletService] For patient ID: $patientId');
      }

      final body = <String, dynamic>{
        'amount': amount,
        'channel': channel,
      };

      if (provider != null) body['provider'] = provider;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (patientId != null) body['patient_id'] = patientId;

      final response = await _apiClient.post(
        ApiConfig.walletDepositEndpoint,
        body: body,
        requiresAuth: true,
      );

      log('✅ [WalletService] Deposit init response received');
      log('🎯 [WalletService] Success: ${response['success']}');

      if (response['success'] == true) {
        log('✅ [WalletService] Deposit initialized successfully');
        log('🔗 [WalletService] Reference: ${response['data']?['reference']}');
        return DepositInitResponse.fromJson(response);
      } else {
        log('❌ [WalletService] Deposit initialization failed');
        throw WalletException(
          message: response['message'] ?? 'Failed to initialize deposit',
        );
      }
    } catch (e) {
      log('💥 [WalletService] Error initiating deposit: $e');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to initialize deposit',
      );
    }
  }

  /// Verify a wallet deposit
  ///
  /// Parameters:
  /// - [reference]: The deposit reference to verify
  /// - [patientId]: Optional patient ID (required for contact persons)
  ///
  /// Returns verification result with updated wallet balance
  Future<DepositVerifyResponse> verifyDeposit(String reference, {int? patientId}) async {
    try {
      log('📡 [WalletService] Verifying deposit...');
      log('🔗 [WalletService] Reference: $reference');
      if (patientId != null) {
        log('👤 [WalletService] For patient ID: $patientId');
      }

      final body = <String, dynamic>{
        'reference': reference,
      };
      if (patientId != null) body['patient_id'] = patientId;

      final response = await _apiClient.post(
        ApiConfig.walletDepositVerifyEndpoint,
        body: body,
        requiresAuth: true,
      );

      log('✅ [WalletService] Deposit verification response received');
      log('🎯 [WalletService] Success: ${response['success']}');

      if (response['success'] == true) {
        log('✅ [WalletService] Deposit verified successfully');
        log('💰 [WalletService] New balance: ${response['data']?['wallet']?['formatted_balance']}');
        return DepositVerifyResponse.fromJson(response);
      } else {
        log('❌ [WalletService] Deposit verification failed');
        throw WalletException(
          message: response['message'] ?? 'Deposit verification failed',
        );
      }
    } catch (e) {
      log('💥 [WalletService] Error verifying deposit: $e');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to verify deposit',
      );
    }
  }

  // ==================== PAY FROM WALLET ====================

  /// Pay from wallet for a care payment
  ///
  /// Parameters:
  /// - [carePaymentId]: The care payment ID to pay
  /// - [patientId]: Optional patient ID (required for contact persons)
  ///
  /// Returns payment result with updated wallet balance
  /// Note: If insufficient balance, returns with isInsufficientBalance = true
  Future<WalletPayResponse> payFromWallet(int carePaymentId, {int? patientId}) async {
    try {
      log('📡 [WalletService] Paying from wallet...');
      log('🔗 [WalletService] Care Payment ID: $carePaymentId');
      if (patientId != null) {
        log('👤 [WalletService] For patient ID: $patientId');
      }
      print('📡 [WalletService] Paying from wallet with carePaymentId: $carePaymentId');

      final body = <String, dynamic>{
        'care_payment_id': carePaymentId,
      };
      if (patientId != null) body['patient_id'] = patientId;

      print('📡 [WalletService] Endpoint: ${ApiConfig.walletPayEndpoint}');
      print('📡 [WalletService] Body: $body');

      final response = await _apiClient.post(
        ApiConfig.walletPayEndpoint,
        body: body,
        requiresAuth: true,
      );

      log('✅ [WalletService] Wallet payment response received');
      log('🎯 [WalletService] Success: ${response['success']}');
      print('✅ [WalletService] Response: $response');

      // Parse response (may include insufficient balance data)
      final walletPayResponse = WalletPayResponse.fromJson(response);

      if (response['success'] == true) {
        log('✅ [WalletService] Payment completed successfully');
        log('💰 [WalletService] New balance: ${response['data']?['wallet']?['formatted_balance']}');
        print('✅ [WalletService] Payment completed successfully');
      } else {
        log('❌ [WalletService] Wallet payment failed: ${response['message']}');
        print('❌ [WalletService] Payment failed: ${response['message']}');
        if (walletPayResponse.isInsufficientBalance) {
          log('⚠️ [WalletService] Insufficient balance detected');
          print('⚠️ [WalletService] Insufficient balance detected');
        }
      }

      return walletPayResponse;
    } catch (e, stackTrace) {
      log('💥 [WalletService] Error paying from wallet: $e');
      print('💥 [WalletService] Exception: $e');
      print('💥 [WalletService] StackTrace: $stackTrace');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to process wallet payment',
      );
    }
  }

  // ==================== TRANSACTION HISTORY ====================

  /// Get wallet transaction history
  ///
  /// Parameters:
  /// - [type]: Filter by transaction type (credit, debit)
  /// - [category]: Filter by category (deposit, payment, refund, etc.)
  /// - [status]: Filter by status (pending, completed, failed)
  /// - [fromDate]: Filter from date (YYYY-MM-DD)
  /// - [toDate]: Filter to date (YYYY-MM-DD)
  /// - [perPage]: Number of items per page (default: 20)
  /// - [page]: Page number (default: 1)
  /// - [patientId]: Optional patient ID (required for contact persons)
  ///
  /// Returns paginated transaction history with summary
  Future<WalletTransactionHistoryResponse> getTransactionHistory({
    String? type,
    String? category,
    String? status,
    String? fromDate,
    String? toDate,
    int perPage = 20,
    int page = 1,
    int? patientId,
  }) async {
    try {
      log('📡 [WalletService] Fetching transaction history...');
      log('📄 [WalletService] Page: $page, PerPage: $perPage');
      if (patientId != null) {
        log('👤 [WalletService] For patient ID: $patientId');
      }

      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      if (patientId != null) {
        queryParams['patient_id'] = patientId.toString();
      }

      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to_date'] = toDate;
      }

      final uri = Uri.parse(ApiConfig.walletTransactionsEndpoint).replace(
        queryParameters: queryParams,
      );

      log('🔗 [WalletService] URL: ${uri.toString()}');

      final response = await _apiClient.get(
        uri.toString(),
        requiresAuth: true,
      );

      log('✅ [WalletService] Transaction history response received');
      log('🎯 [WalletService] Success: ${response['success']}');

      if (response['success'] == true) {
        log('✅ [WalletService] Transaction history fetched successfully');
        log('📊 [WalletService] Total: ${response['data']?['pagination']?['total'] ?? 0}');
        return WalletTransactionHistoryResponse.fromJson(response);
      } else {
        log('❌ [WalletService] Transaction history fetch failed');
        throw WalletException(
          message: response['message'] ?? 'Failed to fetch transaction history',
        );
      }
    } catch (e) {
      log('💥 [WalletService] Error fetching transaction history: $e');
      if (e is WalletException) {
        rethrow;
      }
      throw WalletException(
        message: 'Network error: Unable to fetch transaction history',
      );
    }
  }

  // ==================== CONVENIENCE METHODS ====================

  /// Check if user can pay from wallet
  ///
  /// Parameters:
  /// - [walletBalance]: Current wallet balance
  /// - [amount]: Amount to pay
  ///
  /// Returns true if balance is sufficient
  bool canPayFromWallet(double walletBalance, double amount) {
    return walletBalance >= amount;
  }

  /// Calculate shortfall amount
  ///
  /// Parameters:
  /// - [walletBalance]: Current wallet balance
  /// - [amount]: Amount to pay
  ///
  /// Returns the shortfall amount (0 if balance is sufficient)
  double getShortfall(double walletBalance, double amount) {
    if (walletBalance >= amount) return 0.0;
    return amount - walletBalance;
  }

  /// Format amount with currency
  String formatAmount(double amount, {String currency = 'GHS'}) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  /// Get transaction category display text
  String getCategoryText(String category) {
    final categoryTexts = {
      'deposit': 'Deposit',
      'payment': 'Payment',
      'refund': 'Refund',
      'adjustment': 'Adjustment',
      'withdrawal': 'Withdrawal',
    };
    return categoryTexts[category] ?? category;
  }

  /// Get transaction status display text
  String getStatusText(String status) {
    final statusTexts = {
      'pending': 'Pending',
      'processing': 'Processing',
      'completed': 'Completed',
      'failed': 'Failed',
    };
    return statusTexts[status] ?? status;
  }
}

// ============================================================================
// EXCEPTION CLASS
// ============================================================================

/// Custom exception for Wallet operations
class WalletException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  WalletException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;

  /// Get first error message from errors map
  String? getFirstError() {
    if (errors == null || errors!.isEmpty) return null;

    final firstKey = errors!.keys.first;
    final firstValue = errors![firstKey];

    if (firstValue is List && firstValue.isNotEmpty) {
      return firstValue.first.toString();
    } else if (firstValue is String) {
      return firstValue;
    }

    return null;
  }
}
