import '../utils/api_client.dart';
import '../utils/api_config.dart';

/// A saved card (Paystack reusable authorization) — display data only.
/// The server never returns the raw authorization token.
class SavedPaymentMethod {
  final int id;
  final String displayName;
  final String? cardType;
  final String? last4;
  final String? expMonth;
  final String? expYear;
  final String? bank;
  final bool isDefault;
  final bool isExpired;
  final bool autopayEnabled;
  final String? lastUsedAt;

  SavedPaymentMethod({
    required this.id,
    required this.displayName,
    this.cardType,
    this.last4,
    this.expMonth,
    this.expYear,
    this.bank,
    this.isDefault = false,
    this.isExpired = false,
    this.autopayEnabled = false,
    this.lastUsedAt,
  });

  String get expiryDisplay {
    if (expMonth == null || expYear == null) return '';
    final year = expYear!.length == 4 ? expYear!.substring(2) : expYear!;
    return '${expMonth!.padLeft(2, '0')}/$year';
  }

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      displayName: json['display_name']?.toString() ?? 'Card',
      cardType: json['card_type']?.toString(),
      last4: json['last4']?.toString(),
      expMonth: json['exp_month']?.toString(),
      expYear: json['exp_year']?.toString(),
      bank: json['bank']?.toString(),
      isDefault: json['is_default'] == true,
      isExpired: json['is_expired'] == true,
      autopayEnabled: json['autopay_enabled'] == true,
      lastUsedAt: json['last_used_at']?.toString(),
    );
  }
}

class PaymentMethodsService {
  static final PaymentMethodsService _instance = PaymentMethodsService._internal();
  factory PaymentMethodsService() => _instance;
  PaymentMethodsService._internal();

  final _apiClient = ApiClient();

  /// List the patient's saved cards.
  Future<List<SavedPaymentMethod>> getSavedCards() async {
    final response = await _apiClient.get(
      ApiConfig.patientPaymentMethodsEndpoint,
      requiresAuth: true,
    );

    final data = response['data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((e) => SavedPaymentMethod.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Enable/disable auto-pay for one saved card.
  /// Returns the server message.
  Future<String> setAutopay(int methodId, bool enabled) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.patientPaymentMethodAutopayEndpoint(methodId),
        body: {'enabled': enabled},
        requiresAuth: true,
      );
      return response['message']?.toString() ??
          (enabled ? 'Auto-pay enabled' : 'Auto-pay disabled');
    } on ApiError catch (e) {
      throw Exception(e.displayMessage);
    }
  }

  /// Record that the patient chose "Not Now" on the auto-pay prompt so the
  /// care team can see auto-pay was offered and declined. Best-effort.
  Future<void> dismissAutopayPrompt(int methodId) async {
    try {
      await _apiClient.post(
        ApiConfig.patientPaymentMethodDismissPromptEndpoint(methodId),
        body: {},
        requiresAuth: true,
      );
    } catch (_) {
      // Non-critical; ignore failures
    }
  }

  /// Remove a saved card.
  Future<String> removeCard(int methodId) async {
    try {
      final response = await _apiClient.delete(
        ApiConfig.patientPaymentMethodDeleteEndpoint(methodId),
        requiresAuth: true,
      );
      return response['message']?.toString() ?? 'Card removed';
    } on ApiError catch (e) {
      throw Exception(e.displayMessage);
    }
  }
}
