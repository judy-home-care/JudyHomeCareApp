import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/app_colors.dart';
import '../../../services/payment_methods_service.dart';
import '../../../utils/secure_storage.dart';

/// After a successful CARD payment, offer to enable auto-pay on the card the
/// patient just used ("Save this card for automatic debits?").
///
/// Safe to call after any payment flow:
///  - does nothing for non-patients (contact persons, etc.)
///  - does nothing unless a reusable card was saved in the last few minutes
///    (i.e. this payment was by card — mobile money never qualifies)
///  - does nothing if auto-pay is already on, or the patient dismissed the
///    prompt for this card before (they can still enable it later under
///    Account → Payment Methods)
Future<void> maybePromptForAutopay(BuildContext context) async {
  try {
    // Patients only
    final userData = await SecureStorage().getUserData();
    final role = userData?['role']?.toString();
    if (role != null && role != 'patient') return;

    final cards = await PaymentMethodsService().getSavedCards();
    if (cards.isEmpty) return;
    if (cards.any((c) => c.autopayEnabled)) return;

    // The card used in THIS payment: freshly saved/refreshed by the server
    // during verification moments ago.
    SavedPaymentMethod? justUsed;
    for (final c in cards) {
      if (c.isExpired || c.lastUsedAt == null) continue;
      final lastUsed = DateTime.tryParse(c.lastUsedAt!);
      if (lastUsed == null) continue;
      if (DateTime.now().toUtc().difference(lastUsed.toUtc()).inMinutes.abs() <= 15) {
        justUsed = c;
        break;
      }
    }
    if (justUsed == null) return;

    // Don't nag: one prompt per card unless they re-enable interest
    final prefs = await SharedPreferences.getInstance();
    final dismissKey = 'autopay_prompt_dismissed_${justUsed.id}';
    if (prefs.getBool(dismissKey) == true) return;

    if (!context.mounted) return;

    final enable = await _showAutopaySheet(context, justUsed);

    if (enable == true) {
      final message = await PaymentMethodsService().setAutopay(justUsed.id, true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      await prefs.setBool(dismissKey, true);
      // Let the server know "Not Now" was chosen so the care team can see
      // auto-pay was offered and declined.
      await PaymentMethodsService().dismissAutopayPrompt(justUsed.id);
    }
  } catch (e) {
    // Never let the prompt break the payment success flow
    debugPrint('Auto-pay prompt skipped: $e');
  }
}

Future<bool?> _showAutopaySheet(BuildContext context, SavedPaymentMethod card) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.autorenew_rounded,
                color: AppColors.primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Save card for automatic payments?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We can automatically charge this card whenever an invoice is due, '
              'so you never miss a payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.credit_card, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (card.expiryDisplay.isNotEmpty)
                          Text(
                            'Expires ${card.expiryDisplay}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_user_outlined,
                      color: AppColors.primaryGreen, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your card details stay securely with Paystack — we never store your '
                    'card number or CVV. You get a notification for every charge and can '
                    'turn this off anytime in Payment Methods.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Yes, Enable Auto-Pay',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
