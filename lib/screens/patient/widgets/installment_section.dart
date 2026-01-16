import 'package:flutter/material.dart';
import '../../../models/care_request/care_request_models.dart';
import '../../../models/wallet/wallet_models.dart';
import '../../../services/care_request_service.dart';
import '../../../services/contact_person/contact_person_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/wallet_service.dart';
import '../../../widgets/paystack_webview.dart';

/// Legacy widget kept for backward compatibility
/// All installment info is now shown in Care Payment Summary card in TabbedCareRequestCard
/// This file is kept for the InstallmentPaymentSheet class
class InstallmentSection extends StatelessWidget {
  final CareRequest careRequest;
  final VoidCallback? onPaymentComplete;
  final bool isContactPerson;
  final int? patientId;

  const InstallmentSection({
    Key? key,
    required this.careRequest,
    this.onPaymentComplete,
    this.isContactPerson = false,
    this.patientId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Bottom sheet for making installment payment
class InstallmentPaymentSheet extends StatefulWidget {
  final int careRequestId;
  final Installment installment;
  final bool isContactPerson;
  /// Patient ID for contact person paying on behalf of patient
  final int? patientId;

  const InstallmentPaymentSheet({
    Key? key,
    required this.careRequestId,
    required this.installment,
    this.isContactPerson = false,
    this.patientId,
  }) : super(key: key);

  @override
  State<InstallmentPaymentSheet> createState() => _InstallmentPaymentSheetState();
}

class _InstallmentPaymentSheetState extends State<InstallmentPaymentSheet> {
  final CareRequestService _careRequestService = CareRequestService();
  final ContactPersonService _contactPersonService = ContactPersonService();
  final PaymentService _paymentService = PaymentService();
  final WalletService _walletService = WalletService();

  bool _isProcessing = false;
  bool _isLoadingWallet = true;
  WalletInfo? _walletInfo;
  String _selectedPaymentMethod = 'paystack'; // 'paystack' or 'wallet'

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    print('🔄 [InstallmentSheet] Loading wallet info... patientId=${widget.patientId}');
    try {
      // Pass patientId for contact person viewing patient's wallet
      final response = await _walletService.getWalletInfo(
        patientId: widget.patientId,
      );
      print('📦 [InstallmentSheet] Wallet response: success=${response.success}, data=${response.data}');
      if (mounted && response.success && response.data != null) {
        setState(() {
          _walletInfo = response.data;
          _isLoadingWallet = false;
        });
        print('✅ [InstallmentSheet] Wallet loaded: ${_walletInfo?.formattedBalance}');
      } else {
        setState(() => _isLoadingWallet = false);
        print('⚠️ [InstallmentSheet] Wallet load failed or no data');
      }
    } catch (e) {
      print('❌ [InstallmentSheet] Wallet load error: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  Future<void> _initiatePayment() async {
    print('💳 [InstallmentSheet] Initiating payment with method: $_selectedPaymentMethod');
    if (_selectedPaymentMethod == 'wallet') {
      await _processWalletPayment();
    } else {
      await _processPaystackPayment();
    }
  }

  Future<void> _processWalletPayment() async {
    print('👛 [InstallmentSheet] Processing wallet payment...');
    print('👛 [InstallmentSheet] Installment ID: ${widget.installment.id}');
    print('👛 [InstallmentSheet] Amount: ${widget.installment.amount}');
    final walletBalance = _walletInfo?.balance ?? 0;
    final amountToPay = widget.installment.amount;

    // Check if balance is sufficient
    if (walletBalance < amountToPay) {
      _showInsufficientBalanceDialog(walletBalance, amountToPay);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Get the payment ID for the installment
      final paymentId = widget.installment.id;

      print('👛 [InstallmentSheet] Calling payFromWallet with paymentId: $paymentId, patientId: ${widget.patientId}');

      // Pass patientId for contact person paying on behalf of patient
      final response = await _walletService.payFromWallet(
        paymentId,
        patientId: widget.patientId,
      );

      print('👛 [InstallmentSheet] API Response: success=${response.success}, message=${response.message}');
      print('👛 [InstallmentSheet] isInsufficientBalance=${response.isInsufficientBalance}');

      if (!mounted) {
        print('⚠️ [InstallmentSheet] Widget not mounted after API call');
        return;
      }

      if (response.success) {
        print('✅ [InstallmentSheet] Wallet payment successful!');
        setState(() => _isProcessing = false);
        _showSuccessDialog();
      } else if (response.isInsufficientBalance) {
        print('⚠️ [InstallmentSheet] Insufficient balance');
        setState(() => _isProcessing = false);
        _showInsufficientBalanceDialog(
          response.insufficientBalanceData?.available ?? walletBalance,
          amountToPay,
        );
      } else {
        print('❌ [InstallmentSheet] Payment failed: ${response.message}');
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('💥 [InstallmentSheet] Exception: $e');
      print('💥 [InstallmentSheet] StackTrace: $stackTrace');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInsufficientBalanceDialog(double currentBalance, double requiredAmount) {
    final shortfall = requiredAmount - currentBalance;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.orange.shade700,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Insufficient Balance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            _buildBalanceRow('Current Balance', 'GHS ${currentBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildBalanceRow('Required Amount', 'GHS ${requiredAmount.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildBalanceRow('Shortfall', 'GHS ${shortfall.toStringAsFixed(2)}', isShortfall: true),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      // Switch to Paystack payment
                      setState(() => _selectedPaymentMethod = 'paystack');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF199A8E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Use Paystack',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, {bool isShortfall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isShortfall ? Colors.red : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Future<void> _processPaystackPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Use mobile_money as default channel without phone - this triggers Paystack checkout
      InstallmentPaymentResponse response;
      if (widget.isContactPerson) {
        response = await _contactPersonService.initiateInstallmentPayment(
          requestId: widget.careRequestId,
          paymentId: widget.installment.id,
          paymentMethod: 'mobile_money',
        );
      } else {
        response = await _careRequestService.payInstallment(
          requestId: widget.careRequestId,
          paymentId: widget.installment.id,
          channel: 'mobile_money',
        );
      }

      if (!mounted) return;

      if (response.success && response.data != null) {
        final paymentUrl = response.data!.paymentUrl;
        final reference = response.data!.reference;

        // Debug logging
        print('🔗 [InstallmentPayment] Payment URL: $paymentUrl');
        print('📝 [InstallmentPayment] Reference: $reference');

        if (paymentUrl.isEmpty) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment URL is empty. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() => _isProcessing = false);

        // Navigate to webview for payment - keep bottom sheet open (like CarePaymentScreen)
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackPaymentWebView(
              authorizationUrl: paymentUrl,
              reference: reference,
            ),
            fullscreenDialog: true,
          ),
        );

        if (!mounted) return;

        if (result == true) {
          // Verify payment on backend
          setState(() => _isProcessing = true);
          print('🔄 [InstallmentPayment] Verifying payment with reference: $reference');

          final verifyResponse = await _paymentService.verifyPayment(reference);

          if (!mounted) return;
          setState(() => _isProcessing = false);

          if (verifyResponse.success) {
            print('✅ [InstallmentPayment] Payment verified successfully!');
            // Payment verified successfully - show success dialog
            _showSuccessDialog();
          } else {
            print('❌ [InstallmentPayment] Verification failed: ${verifyResponse.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment verification failed: ${verifyResponse.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Payment was cancelled or failed - show cancel dialog like CarePaymentScreen
          _showCancelDialog();
        }
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show cancellation dialog - allows retry (same as CarePaymentScreen)
  void _showCancelDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: Colors.orange.shade700,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Cancelled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment was cancelled. You can try again or go back.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog
                      Navigator.of(context).pop(); // Close bottom sheet
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog only
                      // Stay on bottom sheet - user can retry
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF199A8E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show success dialog (same pattern as CarePaymentScreen)
  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF199A8E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.installment.label} has been paid successfully. Your payment has been received.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF199A8E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.installment.formattedAmount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF199A8E),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Close bottom sheet with success result
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF199A8E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF199A8E).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF199A8E)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF199A8E).withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF199A8E)
                    : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF199A8E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Color(0xFF199A8E),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay Installment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        widget.installment.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Amount
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Pay',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.installment.formattedAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF199A8E),
                    ),
                  ),
                  if (widget.installment.isOverdue) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'This payment is overdue',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.installment.dueDateFormatted != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Due: ${widget.installment.dueDateFormatted}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Payment method selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                // Wallet Option
                _buildPaymentMethodOption(
                  title: 'Pay from Wallet',
                  subtitle: _isLoadingWallet
                      ? 'Loading balance...'
                      : 'Balance: ${_walletInfo?.formattedBalance ?? 'GHS 0.00'}',
                  icon: Icons.account_balance_wallet,
                  isSelected: _selectedPaymentMethod == 'wallet',
                  isEnabled: !_isLoadingWallet,
                  onTap: () {
                    print('👆 [InstallmentSheet] Wallet option tapped! isLoadingWallet=$_isLoadingWallet');
                    if (!_isLoadingWallet) {
                      setState(() => _selectedPaymentMethod = 'wallet');
                      print('✅ [InstallmentSheet] Selected payment method: wallet');
                    }
                  },
                ),
                const SizedBox(height: 10),
                // Paystack Option
                _buildPaymentMethodOption(
                  title: 'Pay with Paystack',
                  subtitle: 'Card, Mobile Money, Bank',
                  icon: Icons.payment,
                  isSelected: _selectedPaymentMethod == 'paystack',
                  isEnabled: true,
                  onTap: () {
                    print('👆 [InstallmentSheet] Paystack option tapped!');
                    setState(() => _selectedPaymentMethod = 'paystack');
                    print('✅ [InstallmentSheet] Selected payment method: paystack');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Pay button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.installment.isOverdue
                      ? Colors.red
                      : const Color(0xFF199A8E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Pay ${widget.installment.formattedAmount}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
