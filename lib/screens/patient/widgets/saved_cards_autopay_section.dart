import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../services/payment_methods_service.dart';

/// "Saved Cards & Auto-Pay" — shown at the top of the Payment Methods screen.
///
/// Cards appear here automatically after the patient pays once by card
/// (Paystack reusable authorization — no card numbers/CVV are ever stored).
/// The patient can opt in to auto-pay so due invoices are charged
/// automatically, or remove a card.
class SavedCardsAutopaySection extends StatefulWidget {
  const SavedCardsAutopaySection({Key? key}) : super(key: key);

  @override
  State<SavedCardsAutopaySection> createState() => _SavedCardsAutopaySectionState();
}

class _SavedCardsAutopaySectionState extends State<SavedCardsAutopaySection> {
  final _service = PaymentMethodsService();

  List<SavedPaymentMethod> _cards = [];
  bool _isLoading = true;
  int? _busyCardId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await _service.getSavedCards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAutopay(SavedPaymentMethod card, bool enable) async {
    if (enable) {
      final confirmed = await _showConsentDialog(card);
      if (confirmed != true) return;
    }

    setState(() => _busyCardId = card.id);
    try {
      final message = await _service.setAutopay(card.id, enable);
      await _load();
      if (!mounted) return;
      _showSnack(message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  Future<void> _removeCard(SavedPaymentMethod card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Card'),
        content: Text(
          'Remove ${card.displayName}? It will no longer be charged automatically. '
          'You can save it again by paying once with this card.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyCardId = card.id);
    try {
      final message = await _service.removeCard(card.id);
      await _load();
      if (!mounted) return;
      _showSnack(message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  Future<bool?> _showConsentDialog(SavedPaymentMethod card) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.autorenew_rounded, color: AppColors.primaryGreen),
            SizedBox(width: 10),
            Expanded(child: Text('Enable Auto-Pay?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When an invoice is due, we will automatically charge:',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: AppColors.primaryGreen, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    card.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  const Spacer(),
                  if (card.expiryDisplay.isNotEmpty)
                    Text(
                      'Exp ${card.expiryDisplay}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will get a notification for every charge, and you can turn this off anytime. '
              'Your card details stay with Paystack — we never store your card number or CVV.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enable Auto-Pay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Saved Cards & Auto-Pay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2.5),
            ),
          )
        else if (_cards.isEmpty)
          _buildEmptyState()
        else
          ..._cards.map(_buildCardTile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card_outlined, color: Color(0xFF6C63FF), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No saved cards yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pay once with your card and it will appear here so you can enable auto-pay for due invoices.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(SavedPaymentMethod card) {
    final busy = _busyCardId == card.id;
    String? lastUsed;
    if (card.lastUsedAt != null) {
      try {
        lastUsed = DateFormat('MMM d, yyyy').format(DateTime.parse(card.lastUsedAt!));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.autopayEnabled ? AppColors.primaryGreen.withOpacity(0.4) : Colors.grey.shade200,
          width: card.autopayEnabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          card.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                        ),
                        if (card.isExpired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4757).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Expired',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFF4757)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (card.bank != null && card.bank!.isNotEmpty) card.bank!,
                        if (card.expiryDisplay.isNotEmpty) 'Exp ${card.expiryDisplay}',
                        if (lastUsed != null) 'Last used $lastUsed',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => _removeCard(card),
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 20),
                tooltip: 'Remove card',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: card.autopayEnabled
                  ? AppColors.primaryGreen.withOpacity(0.06)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.autorenew_rounded,
                  size: 18,
                  color: card.autopayEnabled ? AppColors.primaryGreen : Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-pay due invoices',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                      ),
                      Text(
                        card.autopayEnabled
                            ? 'Due invoices are charged to this card automatically'
                            : 'Charge this card automatically when an invoice is due',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                  )
                else
                  Switch(
                    value: card.autopayEnabled,
                    onChanged: card.isExpired ? null : (v) => _toggleAutopay(card, v),
                    activeColor: AppColors.primaryGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
