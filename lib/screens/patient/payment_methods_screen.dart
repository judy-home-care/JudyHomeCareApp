import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Secure Payments',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All transactions are encrypted and secure',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Methods List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Available Payment Methods',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mobile Money
            _buildPaymentMethodCard(
              context: context,
              title: 'Mobile Money',
              subtitle: 'Pay with MTN, Airtel, or other mobile networks',
              iconWidget: _buildMobileMoneyIcon(),
              color: const Color(0xFFFFCC00),
              features: ['Instant transfers', 'No hidden fees', 'Available 24/7'],
            ),

            // Mastercard
            _buildPaymentMethodCard(
              context: context,
              title: 'Mastercard',
              subtitle: 'Credit & Debit cards accepted',
              iconWidget: _buildMastercardIcon(),
              color: const Color(0xFFEB001B),
              features: ['Worldwide accepted', 'Secure 3D verification', 'Rewards eligible'],
            ),

            // Visa
            _buildPaymentMethodCard(
              context: context,
              title: 'Visa Card',
              subtitle: 'Credit & Debit cards accepted',
              iconWidget: _buildVisaIcon(),
              color: const Color(0xFF1A1F71),
              features: ['Global acceptance', 'Fraud protection', 'Easy refunds'],
            ),

            // Apple Pay
            _buildPaymentMethodCard(
              context: context,
              title: 'Apple Pay',
              subtitle: 'Fast & secure with Face ID or Touch ID',
              iconWidget: _buildApplePayIcon(),
              color: const Color(0xFF000000),
              features: ['One-tap payment', 'Privacy focused', 'No card numbers shared'],
            ),

            // Bank Transfer
            _buildPaymentMethodCard(
              context: context,
              title: 'Direct Bank Transfer',
              subtitle: 'Transfer directly from your bank account',
              iconWidget: _buildBankTransferIcon(),
              color: const Color(0xFF0066CC),
              features: ['Low fees', 'High limits', 'Bank-level security'],
            ),

            // American Express
            _buildPaymentMethodCard(
              context: context,
              title: 'American Express',
              subtitle: 'Premium card payments',
              iconWidget: _buildAmexIcon(),
              color: const Color(0xFF006FCF),
              features: ['Premium rewards', 'Purchase protection', 'Member benefits'],
            ),

            const SizedBox(height: 30),

            // Info Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0066CC).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066CC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF0066CC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0066CC),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a payment method during checkout. Your payment details are never stored on our servers.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required Color color,
    required List<String> features,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _showPaymentMethodDetails(context, title, subtitle, features, color);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: iconWidget),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Features chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: features.take(2).map((feature) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodDetails(
    BuildContext context,
    String title,
    String subtitle,
    List<String> features,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            // Features
            const Text(
              'Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            // Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can select this payment method during checkout.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // Custom Payment Method Icons

  Widget _buildMobileMoneyIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFCC00), Color(0xFFFF9500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.phone_android,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMastercardIcon() {
    return SizedBox(
      width: 40,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFF79E1B),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisaIcon() {
    return Container(
      width: 40,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'VISA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildApplePayIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.apple,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildBankTransferIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066CC), Color(0xFF0099FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.account_balance,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildAmexIcon() {
    return Container(
      width: 40,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF006FCF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'AMEX',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
