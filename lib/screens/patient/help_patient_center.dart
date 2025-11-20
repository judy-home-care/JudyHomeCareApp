import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class PatientHelpCenterScreen extends StatelessWidget {
  const PatientHelpCenterScreen({Key? key}) : super(key: key);

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: cleanedNumber,
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Unable to make phone call');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error making phone call: $e');
      }
      debugPrint('Error launching phone dialer: $e');
    }
  }

  Future<void> _openEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Support Request - Judy Home HealthCare',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Unable to open email client');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error opening email: $e');
      }
      debugPrint('Error launching email client: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('$feature coming soon!')),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card - Full Width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our support team is here to assist you 24/7',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Contact Options Section - With Padding
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildContactOption(
                    context: context,
                    icon: Icons.phone_outlined,
                    title: 'Call Us',
                    subtitle: '+1 (800) 123-4567',
                    iconColor: const Color(0xFF4CAF50),
                    iconBg: const Color(0xFFE8F5E9),
                    onTap: () => _makePhoneCall(context, '+18001234567'),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildContactOption(
                    context: context,
                    icon: Icons.email_outlined,
                    title: 'Email Support',
                    subtitle: 'support@judyhealthcare.com',
                    iconColor: const Color(0xFF2196F3),
                    iconBg: const Color(0xFFE3F2FD),
                    onTap: () => _openEmail(context, 'support@judyhealthcare.com'),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Quick Links Section
                  Text(
                    'Quick Links',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildQuickLink(
                    context: context,
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _showComingSoonSnackBar(context, 'Privacy Policy'),
                  ),
                  
                  _buildQuickLink(
                    context: context,
                    title: 'Terms of Service',
                    icon: Icons.description_outlined,
                    onTap: () => _showComingSoonSnackBar(context, 'Terms of Service'),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Operating Hours Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.access_time,
                                size: 20,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Operating Hours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildOperatingHour('Monday - Friday', '8:00 AM - 6:00 PM'),
                        const SizedBox(height: 8),
                        _buildOperatingHour('Saturday', '9:00 AM - 4:00 PM'),
                        const SizedBox(height: 8),
                        _buildOperatingHour('Sunday', 'Closed'),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.emergency,
                              size: 18,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency support available 24/7',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildQuickLink({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatingHour(String day, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          hours,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}