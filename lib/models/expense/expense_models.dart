/// Expense Models

class Expense {
  final int id;
  final int patientId;
  final double totalAmount;
  final String currency;
  final String description;
  final bool deductFromWallet;
  final int? walletTransactionId;
  final String status;
  final int? createdBy;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String formattedTotalAmount;
  final List<ExpenseItem> items;
  final ExpenseCreator? createdByRelation;
  final ExpenseWalletTransaction? walletTransaction;

  Expense({
    required this.id,
    required this.patientId,
    required this.totalAmount,
    required this.currency,
    required this.description,
    required this.deductFromWallet,
    this.walletTransactionId,
    required this.status,
    this.createdBy,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.formattedTotalAmount,
    required this.items,
    this.createdByRelation,
    this.walletTransaction,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? 0,
      patientId: json['patient_id'] ?? 0,
      totalAmount: _parseDouble(json['total_amount']),
      currency: json['currency'] ?? 'GHS',
      description: json['description'] ?? '',
      deductFromWallet: json['deduct_from_wallet'] ?? false,
      walletTransactionId: json['wallet_transaction_id'] is int
          ? json['wallet_transaction_id']
          : null,
      status: json['status'] ?? 'completed',
      createdBy: json['created_by'] is int ? json['created_by'] : null,
      metadata: json['metadata'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
      formattedTotalAmount: json['formatted_total_amount'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ExpenseItem.fromJson(e))
              .toList() ??
          [],
      createdByRelation: json['created_by_relation'] != null
          ? ExpenseCreator.fromJson(json['created_by_relation'])
          : null,
      walletTransaction: json['wallet_transaction'] != null
          ? ExpenseWalletTransaction.fromJson(json['wallet_transaction'])
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class ExpenseItem {
  final int id;
  final int expenseId;
  final String name;
  final double amount;
  final String formattedAmount;
  final DateTime? createdAt;

  ExpenseItem({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.amount,
    required this.formattedAmount,
    this.createdAt,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id'] ?? 0,
      expenseId: json['expense_id'] ?? 0,
      name: json['name'] ?? '',
      amount: Expense._parseDouble(json['amount']),
      formattedAmount: json['formatted_amount'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class ExpenseCreator {
  final int id;
  final String firstName;
  final String lastName;

  ExpenseCreator({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  factory ExpenseCreator.fromJson(Map<String, dynamic> json) {
    return ExpenseCreator(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class ExpenseWalletTransaction {
  final int id;
  final String type;
  final String category;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String currency;
  final String? reference;
  final String status;
  final String? description;

  ExpenseWalletTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.currency,
    this.reference,
    required this.status,
    this.description,
  });

  factory ExpenseWalletTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseWalletTransaction(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      amount: Expense._parseDouble(json['amount']),
      balanceBefore: Expense._parseDouble(json['balance_before']),
      balanceAfter: Expense._parseDouble(json['balance_after']),
      currency: json['currency'] ?? 'GHS',
      reference: json['reference'],
      status: json['status'] ?? '',
      description: json['description'],
    );
  }
}

class ExpenseSummary {
  final int totalCount;
  final double totalAmount;
  final double walletDeductedAmount;
  final double nonWalletAmount;

  ExpenseSummary({
    required this.totalCount,
    required this.totalAmount,
    required this.walletDeductedAmount,
    required this.nonWalletAmount,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      totalCount: json['total_count'] ?? 0,
      totalAmount: Expense._parseDouble(json['total_amount']),
      walletDeductedAmount: Expense._parseDouble(json['wallet_deducted_amount']),
      nonWalletAmount: Expense._parseDouble(json['non_wallet_amount']),
    );
  }
}

class ExpensePagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  ExpensePagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory ExpensePagination.fromJson(Map<String, dynamic> json) {
    return ExpensePagination(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 20,
      total: json['total'] ?? 0,
    );
  }

  bool get hasNextPage => currentPage < lastPage;
}

class ExpenseListResponse {
  final bool success;
  final List<Expense> expenses;
  final ExpensePagination? pagination;
  final ExpenseSummary? summary;

  ExpenseListResponse({
    required this.success,
    required this.expenses,
    this.pagination,
    this.summary,
  });

  factory ExpenseListResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseListResponse(
      success: json['success'] ?? false,
      expenses: (json['data'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? ExpensePagination.fromJson(json['pagination'])
          : null,
      summary: json['summary'] != null
          ? ExpenseSummary.fromJson(json['summary'])
          : null,
    );
  }
}

class ExpenseDetailResponse {
  final bool success;
  final Expense? data;

  ExpenseDetailResponse({
    required this.success,
    this.data,
  });

  factory ExpenseDetailResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseDetailResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? Expense.fromJson(json['data']) : null,
    );
  }
}
