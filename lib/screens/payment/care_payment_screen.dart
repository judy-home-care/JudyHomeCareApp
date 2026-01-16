// lib/screens/payment/care_payment_screen.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/payment_service.dart';
import '../../services/wallet_service.dart';
import '../../models/care_request/care_request_models.dart';
import '../../models/wallet/wallet_models.dart';
import '../wallet/wallet_deposit_screen.dart';
import '../../utils/app_colors.dart';

class CarePaymentScreen extends StatefulWidget {
  final CareRequest careRequest;
  final double assessmentFee;
  final bool isCarePayment;
  /// Optional patient ID for contact person paying on behalf of patient
  final int? patientId;

  const CarePaymentScreen({
    Key? key,
    required this.careRequest,
    required this.assessmentFee,
    this.isCarePayment = false,
    this.patientId,
  }) : super(key: key);

  @override
  State<CarePaymentScreen> createState() => _CarePaymentScreenState();
}

class _CarePaymentScreenState extends State<CarePaymentScreen> {
  final _paymentService = PaymentService();
  final _walletService = WalletService();

  bool _isProcessing = false;
  bool _isLoadingWallet = true;
  String? _errorMessage;

  // Payment method selection
  String _selectedPaymentMethod = 'paystack'; // 'paystack' or 'wallet'
  WalletInfo? _walletInfo;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    setState(() => _isLoadingWallet = true);
    try {
      // Pass patientId for contact person viewing patient's wallet
      final response = await _walletService.getWalletInfo(
        patientId: widget.patientId,
      );
      if (mounted && response.success) {
        setState(() {
          _walletInfo = response.data;
          _isLoadingWallet = false;
        });
      } else {
        setState(() => _isLoadingWallet = false);
      }
    } catch (e) {
      log('Failed to load wallet info: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Process payment based on selected method
  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'wallet') {
      await _processWalletPayment();
    } else {
      await _processPaystackPayment();
    }
  }

  /// Process wallet payment
  Future<void> _processWalletPayment() async {
    // Check if wallet has sufficient balance
    final walletBalance = _walletInfo?.balance ?? 0;
    if (walletBalance < widget.assessmentFee) {
      _showInsufficientBalanceDialog(walletBalance);
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      log('🚀 [PaymentScreen] Processing wallet payment...');

      // Get the payment ID for this care request
      // Use carePayment if isCarePayment, otherwise use assessmentPayment
      final payment = widget.isCarePayment
          ? widget.careRequest.carePayment
          : widget.careRequest.assessmentPayment;

      if (payment == null) {
        setState(() => _isProcessing = false);
        _showError('Payment information not found. Please try again later.');
        return;
      }

      // Pass patientId for contact person paying on behalf of patient
      final response = await _walletService.payFromWallet(
        payment.id,
        patientId: widget.patientId,
      );

      setState(() => _isProcessing = false);

      if (response.success) {
        log('✅ [PaymentScreen] Wallet payment successful!');
        _showWalletSuccessDialog(response);
      } else if (response.isInsufficientBalance) {
        log('⚠️ [PaymentScreen] Insufficient balance');
        final shortfall = response.insufficientBalanceData?.shortfall ??
            (widget.assessmentFee - (response.insufficientBalanceData?.available ?? 0));
        _showInsufficientBalanceDialog(response.insufficientBalanceData?.available ?? 0);
      } else {
        log('❌ [PaymentScreen] Wallet payment failed: ${response.message}');
        _showError(response.message ?? 'Payment failed');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      log('💥 [PaymentScreen] Wallet payment error: $e');
      _showError('Payment failed: ${e.toString()}');
    }
  }

  /// Process Paystack payment - simplified to use Paystack's payment page
  Future<void> _processPaystackPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      log('🚀 [PaymentScreen] Initializing Paystack payment...');

      // Send mobile_money channel WITHOUT phone_number
      // This triggers the backend's else block which shows ALL payment options
      // (Mobile Money, Card, Bank Transfer)
      final initResponse = await _paymentService.initializePayment(
        widget.careRequest.id,
        channel: 'mobile_money',  // Required by backend
        // No phone_number - this makes backend use default all channels
      );

      if (!initResponse.success || initResponse.data == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = initResponse.message;
        });
        _showError(initResponse.message);
        return; // Stay on page for retry
      }

      final paymentData = initResponse.data!;
      final authorizationUrl = paymentData.authorizationUrl;
      final reference = paymentData.reference;

      log('✅ [PaymentScreen] Payment initialized');
      log('🔗 [PaymentScreen] Authorization URL: $authorizationUrl');
      log('📝 [PaymentScreen] Reference: $reference');

      setState(() => _isProcessing = false);

      // Open Paystack payment page in webview
      final paymentSuccessful = await _openPaymentWebView(
        authorizationUrl,
        reference
      );

      if (paymentSuccessful) {
        // Verify payment on backend
        setState(() => _isProcessing = true);
        log('🔄 [PaymentScreen] Verifying payment...');

        final verifyResponse = await _paymentService.verifyPayment(reference);
        setState(() => _isProcessing = false);

        if (verifyResponse.success) {
          log('✅ [PaymentScreen] Payment verified successfully!');
          _showSuccessDialog(verifyResponse.data);
        } else {
          log('❌ [PaymentScreen] Verification failed: ${verifyResponse.message}');
          _showError(verifyResponse.message);
        }
      } else {
        // Payment was cancelled or failed
        log('❌ [PaymentScreen] Payment cancelled or failed');
        _showCancelDialog();
      }

    } catch (e, stackTrace) {
      setState(() => _isProcessing = false);
      log('💥 [PaymentScreen] Payment Error: $e');
      log('💥 [PaymentScreen] Stack trace: $stackTrace');
      _showError('Payment failed: ${e.toString()}');
    }
  }

  /// Show insufficient balance dialog with option to deposit
  void _showInsufficientBalanceDialog(double availableBalance) {
    if (!mounted) return;

    final shortfall = widget.assessmentFee - availableBalance;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                Icons.account_balance_wallet_outlined,
                color: Colors.orange.shade700,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Insufficient Balance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need GHS ${widget.assessmentFee.toStringAsFixed(2)} but only have GHS ${availableBalance.toStringAsFixed(2)} in your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Shortfall: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                    ),
                  ),
                  Text(
                    'GHS ${shortfall.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Navigate to deposit screen with pre-filled shortfall amount
                      // Pass patientId for contact person depositing to patient's wallet
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalletDepositScreen(
                            patientData: {},
                            prefilledAmount: shortfall,
                            patientId: widget.patientId,
                          ),
                        ),
                      );
                      // Refresh wallet info after deposit
                      if (result == true) {
                        _loadWalletInfo();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Deposit',
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

  /// Show wallet payment success dialog
  void _showWalletSuccessDialog(WalletPayResponse response) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
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
              'Your payment has been completed successfully using your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            if (response.wallet != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New Balance: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      response.wallet!.formattedBalance,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to requests with success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
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

  /// Show cancellation dialog - allows retry
  void _showCancelDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              'Your payment was cancelled. You can try again or go back to your requests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(false); // Go back to requests
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
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog only
                      // Stay on payment screen - user can retry
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

  /// Open Paystack payment page in webview
  Future<bool> _openPaymentWebView(String url, String reference) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaystackPaymentWebView(
          authorizationUrl: url,
          reference: reference,
        ),
        fullscreenDialog: true,
      ),
    );

    return result ?? false;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: const Color(0xFF199A8E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic>? data) {
    if (!mounted) return;
    
    final title = widget.isCarePayment ? 'Payment Successful!' : 'Assessment Fee Paid!';
    final message = widget.isCarePayment
        ? 'Your care service payment has been received. Your care will begin shortly according to your care plan.'
        : 'Your assessment fee has been received. A nurse will be assigned to you shortly.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to care request list
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.isCarePayment ? 'Care Service Payment' : 'Assessment Fee Payment',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPaymentSummaryCard(),
          const SizedBox(height: 24),
          _buildPaymentMethodSelection(),
          const SizedBox(height: 32),
          _buildPayButton(),
          const SizedBox(height: 16),
          _buildSecurityBadges(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),

          // Paystack option
          _buildPaymentMethodOption(
            value: 'paystack',
            icon: Icons.payment,
            title: 'Pay with Paystack',
            subtitle: 'Card, Mobile Money, Bank',
            isSelected: _selectedPaymentMethod == 'paystack',
          ),

          const SizedBox(height: 12),

          // Wallet option
          _buildPaymentMethodOption(
            value: 'wallet',
            icon: Icons.account_balance_wallet,
            title: 'Pay from Wallet',
            subtitle: _isLoadingWallet
                ? 'Loading balance...'
                : 'Balance: ${_walletInfo?.formattedBalance ?? 'GHS 0.00'}',
            isSelected: _selectedPaymentMethod == 'wallet',
            showBadge: _walletInfo != null &&
                (_walletInfo!.balance) >= widget.assessmentFee,
            badgeText: 'Sufficient',
            showInsufficientWarning: _walletInfo != null &&
                (_walletInfo!.balance) < widget.assessmentFee,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool showBadge = false,
    String? badgeText,
    bool showInsufficientWarning = false,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.grey.shade800,
                        ),
                      ),
                      if (showBadge && badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (showInsufficientWarning) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Insufficient balance - deposit to pay',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
              activeColor: AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF199A8E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isCarePayment ? Icons.local_hospital : Icons.account_balance_wallet,
                  color: const Color(0xFF199A8E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isCarePayment ? 'Care Service Payment' : 'Assessment Fee Payment',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.isCarePayment 
                  ? 'Payment for your home care services based on the care plan created for you'
                  : 'One-time payment to begin the assessment process',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Request ID', '#${widget.careRequest.id}'),
          _buildDetailRow('Care Type', _formatCareType(widget.careRequest.careType)),
          _buildDetailRow('Status', _formatStatus(widget.careRequest.status)),
          _buildDetailRow('Urgency', _formatUrgency(widget.careRequest.urgencyLevel)),
          const Divider(height: 32),
          _buildDetailRow(
            widget.isCarePayment ? 'Care Service Fee' : 'Assessment Fee',
            'GHS ${widget.assessmentFee.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF199A8E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payment,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Secure Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Pay Now" to complete your payment securely. You\'ll be able to choose from:\n\n• Mobile Money (MTN, Vodafone, AirtelTigo)\n• Debit/Credit Card (Visa, Mastercard)\n• Bank Transfer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadges() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Powered by Paystack',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment details are handled by Paystack\'s PCI-DSS certified platform. We never see or store your sensitive information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    final isWalletPayment = _selectedPaymentMethod == 'wallet';
    final buttonText = isWalletPayment
        ? 'Pay from Wallet - GHS ${widget.assessmentFee.toStringAsFixed(2)}'
        : 'Pay with Paystack - GHS ${widget.assessmentFee.toStringAsFixed(2)}';
    final buttonIcon = isWalletPayment
        ? Icons.account_balance_wallet
        : Icons.lock_outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade300,
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
                    Icon(
                      buttonIcon,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 20 : 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? const Color(0xFF199A8E) : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCareType(String careType) {
    if (careType.isEmpty) return 'N/A';
    
    return careType.split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'N/A';
    
    return status.split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
  }

  String _formatUrgency(String urgency) {
    if (urgency.isEmpty) return 'N/A';
    
    return urgency[0].toUpperCase() + urgency.substring(1).toLowerCase();
  }
}

/// WebView screen to handle Paystack payment
class PaystackPaymentWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackPaymentWebView({
    Key? key,
    required this.authorizationUrl,
    required this.reference,
  }) : super(key: key);

  @override
  State<PaystackPaymentWebView> createState() => _PaystackPaymentWebViewState();
}

class _PaystackPaymentWebViewState extends State<PaystackPaymentWebView> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;
  bool _paymentDetectedAsSuccessful = false;
  Timer? _successCheckTimer;

  @override
  void dispose() {
    _successCheckTimer?.cancel();
    super.dispose();
  }

  /// Periodically check page content for success message
  void _startSuccessCheck() {
    _successCheckTimer?.cancel();
    _successCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_paymentDetectedAsSuccessful || _webViewController == null) {
        timer.cancel();
        return;
      }

      try {
        final pageContent = await _webViewController!.evaluateJavascript(
          source: "document.body.innerText"
        );
        
        if (pageContent != null) {
          final content = pageContent.toString().toLowerCase();
          if (content.contains('payment successful') ||
              content.contains('transaction successful') ||
              content.contains('payment complete')) {
            log('✅ [WebView] Success detected via periodic check!');
            timer.cancel();
            setState(() => _paymentDetectedAsSuccessful = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.pop(context, true);
          }
        }
      } catch (e) {
        // Ignore errors during periodic check
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If payment was successful, just close without confirmation
        if (_paymentDetectedAsSuccessful) {
          Navigator.pop(context, true);
          return false;
        }
        
        // Otherwise, confirm before closing
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: const Text('Are you sure you want to cancel this payment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );
        
        if (shouldPop == true) {
          Navigator.pop(context, false);
        }
        
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Complete Payment',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () async {
              final shouldCancel = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Cancel Payment?'),
                  content: const Text(
                    'Are you sure you want to cancel this payment? You will be returned to your care requests.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No, Continue'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              
              if (shouldCancel == true && mounted) {
                Navigator.pop(context, false);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.authorizationUrl),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useOnLoadResource: true,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                log('🌐 [WebView] Created for payment: ${widget.reference}');
                // Start periodic success check
                _startSuccessCheck();
              },
              onLoadStart: (controller, url) {
                log('🔄 [WebView] Load started: $url');
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoading = false);
                log('✅ [WebView] Load stopped: $url');
                
                final urlString = url.toString().toLowerCase();
                
                // Check if payment was successful - Paystack success indicators
                if (urlString.contains('success') || 
                    urlString.contains('successful') ||
                    urlString.contains('payment/callback') ||
                    urlString.contains('trxref=${widget.reference.toLowerCase()}') ||
                    urlString.contains('reference=${widget.reference.toLowerCase()}') ||
                    urlString.contains('status=success')) {
                  log('✅ [WebView] Payment success detected via URL');
                  setState(() => _paymentDetectedAsSuccessful = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) Navigator.pop(context, true);
                  return;
                } else if (urlString.contains('cancel') || 
                           urlString.contains('cancelled') ||
                           urlString.contains('failed') ||
                           urlString.contains('error') ||
                           urlString.contains('status=failed')) {
                  log('❌ [WebView] Payment failed or cancelled');
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) Navigator.pop(context, false);
                  return;
                }
                
                // Check page title
                try {
                  final pageTitle = await controller.getTitle();
                  log('📄 [WebView] Page title: $pageTitle');
                  
                  if (pageTitle != null && 
                      (pageTitle.toLowerCase().contains('success') ||
                       pageTitle.toLowerCase().contains('complete') ||
                       pageTitle.toLowerCase().contains('approved') ||
                       pageTitle.toLowerCase().contains('transaction successful'))) {
                    log('✅ [WebView] Success detected via page title');
                    setState(() => _paymentDetectedAsSuccessful = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) Navigator.pop(context, true);
                    return;
                  }
                } catch (e) {
                  log('⚠️ [WebView] Could not read page title: $e');
                }
                
                // 🔥 NEW: Check page content for "Payment Successful" text
                try {
                  await Future.delayed(const Duration(milliseconds: 500));
                  final pageContent = await controller.evaluateJavascript(
                    source: "document.body.innerText"
                  );
                  
                  log('📝 [WebView] Page content check: ${pageContent?.toString().substring(0, 200)}...');
                  
                  if (pageContent != null) {
                    final content = pageContent.toString().toLowerCase();
                    if (content.contains('payment successful') ||
                        content.contains('transaction successful') ||
                        content.contains('payment complete') ||
                        content.contains('transaction complete')) {
                      log('✅ [WebView] Success detected via page content!');
                      setState(() => _paymentDetectedAsSuccessful = true);
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) Navigator.pop(context, true);
                      return;
                    }
                  }
                } catch (e) {
                  log('⚠️ [WebView] Could not read page content: $e');
                }
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                  _isLoading = progress < 100;
                });
              },
              onLoadError: (controller, url, code, message) {
                log('💥 [WebView] Load error: $message (Code: $code)');
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url.toString();
                log('🔗 [WebView] URL loading: $url');
                
                // Allow navigation
                return NavigationActionPolicy.ALLOW;
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading secure payment page...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_progress < 1.0 && !_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                ),
              ),
            // Show "Continue" button when payment is successful
            if (_paymentDetectedAsSuccessful)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF199A8E), Color(0xFF147A70)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Payment Successful - Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}