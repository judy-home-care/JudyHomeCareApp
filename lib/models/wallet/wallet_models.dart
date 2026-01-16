// lib/models/wallet/wallet_models.dart

/// Core wallet information model
class WalletInfo {
  final int walletId;
  final double balance;
  final String formattedBalance;
  final String currency;
  final String status;
  final bool isActive;
  final DateTime? lastTransactionAt;

  WalletInfo({
    required this.walletId,
    required this.balance,
    required this.formattedBalance,
    required this.currency,
    required this.status,
    required this.isActive,
    this.lastTransactionAt,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      walletId: json['wallet_id'] ?? 0,
      balance: _parseDouble(json['balance']),
      formattedBalance: json['formatted_balance'] ?? 'GHS 0.00',
      currency: json['currency'] ?? 'GHS',
      status: json['status'] ?? 'active',
      isActive: json['is_active'] ?? true,
      lastTransactionAt: json['last_transaction_at'] != null
          ? DateTime.parse(json['last_transaction_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'balance': balance,
      'formatted_balance': formattedBalance,
      'currency': currency,
      'status': status,
      'is_active': isActive,
      'last_transaction_at': lastTransactionAt?.toIso8601String(),
    };
  }

  // Helper getters
  bool get hasBalance => balance > 0;
  bool get isInactive => status != 'active' || !isActive;
}

/// Payment configuration for wallet deposits
class WalletPaymentConfig {
  final String publicKey;
  final List<String> channels;
  final List<String> mobileMoneyProviders;
  final String currency;
  final double minDeposit;
  final double maxDeposit;

  WalletPaymentConfig({
    required this.publicKey,
    required this.channels,
    required this.mobileMoneyProviders,
    required this.currency,
    required this.minDeposit,
    required this.maxDeposit,
  });

  factory WalletPaymentConfig.fromJson(Map<String, dynamic> json) {
    return WalletPaymentConfig(
      publicKey: json['public_key'] ?? '',
      channels: List<String>.from(json['channels'] ?? []),
      mobileMoneyProviders: List<String>.from(json['mobile_money_providers'] ?? []),
      currency: json['currency'] ?? 'GHS',
      minDeposit: _parseDouble(json['min_deposit']),
      maxDeposit: _parseDouble(json['max_deposit']),
    );
  }
}

/// Single wallet transaction
class WalletTransaction {
  final int id;
  final String reference;
  final String type; // 'credit', 'debit'
  final String category; // 'deposit', 'payment', 'refund', 'adjustment', 'withdrawal'
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final String? description;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? completedAt;

  WalletTransaction({
    required this.id,
    required this.reference,
    required this.type,
    required this.category,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    this.description,
    this.paymentMethod,
    required this.createdAt,
    this.completedAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      amount: _parseDouble(json['amount']),
      balanceBefore: _parseDouble(json['balance_before']),
      balanceAfter: _parseDouble(json['balance_after']),
      status: json['status'] ?? 'pending',
      description: json['description'],
      paymentMethod: json['payment_method'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'type': type,
      'category': category,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'status': status,
      'description': description,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // Helper getters
  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed';

  String get formattedAmount => '${isCredit ? '+' : '-'}GHS ${amount.toStringAsFixed(2)}';

  String get formattedCategory {
    switch (category) {
      case 'deposit':
        return 'Deposit';
      case 'payment':
        return 'Payment';
      case 'refund':
        return 'Refund';
      case 'adjustment':
        return 'Adjustment';
      case 'withdrawal':
        return 'Withdrawal';
      default:
        return category;
    }
  }

  String get formattedStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}

/// Pagination info for transaction history
class WalletPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  WalletPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory WalletPagination.fromJson(Map<String, dynamic> json) {
    return WalletPagination(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 20,
      total: json['total'] ?? 0,
    );
  }

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPrevPage => currentPage > 1;
}

/// Summary of wallet transactions
class WalletTransactionSummary {
  final double totalDeposits;
  final double totalPayments;
  final double currentBalance;

  WalletTransactionSummary({
    required this.totalDeposits,
    required this.totalPayments,
    required this.currentBalance,
  });

  factory WalletTransactionSummary.fromJson(Map<String, dynamic> json) {
    return WalletTransactionSummary(
      totalDeposits: _parseDouble(json['total_deposits']),
      totalPayments: _parseDouble(json['total_payments']),
      currentBalance: _parseDouble(json['current_balance']),
    );
  }
}

/// Deposit initialization data
class DepositInitData {
  final int transactionId;
  final String reference;
  final double amount;
  final String authorizationUrl;
  final String accessCode;

  DepositInitData({
    required this.transactionId,
    required this.reference,
    required this.amount,
    required this.authorizationUrl,
    required this.accessCode,
  });

  factory DepositInitData.fromJson(Map<String, dynamic> json) {
    return DepositInitData(
      transactionId: json['transaction_id'] ?? 0,
      reference: json['reference'] ?? '',
      amount: _parseDouble(json['amount']),
      authorizationUrl: json['authorization_url'] ?? '',
      accessCode: json['access_code'] ?? '',
    );
  }
}

/// Wallet balance update (returned after transactions)
class WalletBalanceUpdate {
  final double balance;
  final String formattedBalance;

  WalletBalanceUpdate({
    required this.balance,
    required this.formattedBalance,
  });

  factory WalletBalanceUpdate.fromJson(Map<String, dynamic> json) {
    return WalletBalanceUpdate(
      balance: _parseDouble(json['balance']),
      formattedBalance: json['formatted_balance'] ?? 'GHS 0.00',
    );
  }
}

/// Care payment info (returned after wallet payment)
class CarePaymentInfo {
  final int id;
  final String status;
  final String paymentMethod;
  final DateTime? paidAt;

  CarePaymentInfo({
    required this.id,
    required this.status,
    required this.paymentMethod,
    this.paidAt,
  });

  factory CarePaymentInfo.fromJson(Map<String, dynamic> json) {
    return CarePaymentInfo(
      id: json['id'] ?? 0,
      status: json['status'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}

/// Insufficient balance error data
class InsufficientBalanceData {
  final double required;
  final double available;
  final double shortfall;

  InsufficientBalanceData({
    required this.required,
    required this.available,
    required this.shortfall,
  });

  factory InsufficientBalanceData.fromJson(Map<String, dynamic> json) {
    return InsufficientBalanceData(
      required: _parseDouble(json['required']),
      available: _parseDouble(json['available']),
      shortfall: _parseDouble(json['shortfall']),
    );
  }

  String get formattedRequired => 'GHS ${required.toStringAsFixed(2)}';
  String get formattedAvailable => 'GHS ${available.toStringAsFixed(2)}';
  String get formattedShortfall => 'GHS ${shortfall.toStringAsFixed(2)}';
}

// ==================== API RESPONSE WRAPPERS ====================

/// Response for GET /api/mobile/wallet
class WalletInfoResponse {
  final bool success;
  final String? message;
  final WalletInfo? data;

  WalletInfoResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory WalletInfoResponse.fromJson(Map<String, dynamic> json) {
    return WalletInfoResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? WalletInfo.fromJson(json['data']) : null,
    );
  }
}

/// Response for GET /api/mobile/wallet/payment-config
class WalletPaymentConfigResponse {
  final bool success;
  final String? message;
  final WalletPaymentConfig? data;

  WalletPaymentConfigResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory WalletPaymentConfigResponse.fromJson(Map<String, dynamic> json) {
    return WalletPaymentConfigResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? WalletPaymentConfig.fromJson(json['data']) : null,
    );
  }
}

/// Response for POST /api/mobile/wallet/deposit
class DepositInitResponse {
  final bool success;
  final String? message;
  final DepositInitData? data;

  DepositInitResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory DepositInitResponse.fromJson(Map<String, dynamic> json) {
    return DepositInitResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? DepositInitData.fromJson(json['data']) : null,
    );
  }
}

/// Response for POST /api/mobile/wallet/deposit/verify
class DepositVerifyResponse {
  final bool success;
  final String? message;
  final WalletTransaction? transaction;
  final WalletBalanceUpdate? wallet;

  DepositVerifyResponse({
    required this.success,
    this.message,
    this.transaction,
    this.wallet,
  });

  factory DepositVerifyResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return DepositVerifyResponse(
      success: json['success'] ?? false,
      message: json['message'],
      transaction: data?['transaction'] != null
          ? WalletTransaction.fromJson(data!['transaction'])
          : null,
      wallet: data?['wallet'] != null
          ? WalletBalanceUpdate.fromJson(data!['wallet'])
          : null,
    );
  }
}

/// Response for POST /api/mobile/wallet/pay
class WalletPayResponse {
  final bool success;
  final String? message;
  final WalletTransaction? transaction;
  final CarePaymentInfo? carePayment;
  final WalletBalanceUpdate? wallet;
  final InsufficientBalanceData? insufficientBalanceData;

  WalletPayResponse({
    required this.success,
    this.message,
    this.transaction,
    this.carePayment,
    this.wallet,
    this.insufficientBalanceData,
  });

  factory WalletPayResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    // Check if this is an insufficient balance response
    InsufficientBalanceData? insufficientData;
    if (json['success'] == false && data != null) {
      if (data.containsKey('required') && data.containsKey('available')) {
        insufficientData = InsufficientBalanceData.fromJson(data);
      }
    }

    return WalletPayResponse(
      success: json['success'] ?? false,
      message: json['message'],
      transaction: data?['transaction'] != null
          ? WalletTransaction.fromJson(data!['transaction'])
          : null,
      carePayment: data?['care_payment'] != null
          ? CarePaymentInfo.fromJson(data!['care_payment'])
          : null,
      wallet: data?['wallet'] != null
          ? WalletBalanceUpdate.fromJson(data!['wallet'])
          : null,
      insufficientBalanceData: insufficientData,
    );
  }

  bool get isInsufficientBalance =>
      !success && message?.toLowerCase().contains('insufficient') == true;
}

/// Response for GET /api/mobile/wallet/transactions
class WalletTransactionHistoryResponse {
  final bool success;
  final String? message;
  final List<WalletTransaction> transactions;
  final WalletPagination? pagination;
  final WalletTransactionSummary? summary;

  WalletTransactionHistoryResponse({
    required this.success,
    this.message,
    required this.transactions,
    this.pagination,
    this.summary,
  });

  factory WalletTransactionHistoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    List<WalletTransaction> transactionsList = [];
    if (data?['transactions'] != null) {
      transactionsList = (data!['transactions'] as List)
          .map((t) => WalletTransaction.fromJson(t))
          .toList();
    }

    return WalletTransactionHistoryResponse(
      success: json['success'] ?? false,
      message: json['message'],
      transactions: transactionsList,
      pagination: data?['pagination'] != null
          ? WalletPagination.fromJson(data!['pagination'])
          : null,
      summary: data?['summary'] != null
          ? WalletTransactionSummary.fromJson(data!['summary'])
          : null,
    );
  }
}

// ==================== HELPER FUNCTIONS ====================

/// Parse dynamic value to double safely
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}
