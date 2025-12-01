import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/api_config.dart';
import '../../services/auth/auth_service.dart';
import '../../services/messages/message_service.dart';
import '../profile/profile_screen.dart';
import '../password_security/password_security.dart';
import '../transport/transport_request_screen.dart';
import '../help_center.dart';
import '../onboarding/login_signup_screen.dart';
import '../messages/conversations_screen.dart';
import 'patient_notification_preferences.dart';
import 'patient_faq_screen.dart';
import 'help_patient_center.dart'; 

class PatientAccountScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  
  const PatientAccountScreen({
    Key? key,
    required this.patientData,
  }) : super(key: key);

  @override
  State<PatientAccountScreen> createState() => _PatientAccountScreenState();
}

class _PatientAccountScreenState extends State<PatientAccountScreen>
    with AutomaticKeepAliveClientMixin {

  final _authService = AuthService();
  final _messageService = MessageService();

  // ✅ Create a mutable copy of patientData that can be updated
  late Map<String, dynamic> _currentPatientData;

  // Message unread count
  int _unreadMessageCount = 0;
  
  // Keep screen alive in IndexedStack
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // ✅ Initialize with widget data
    _currentPatientData = Map<String, dynamic>.from(widget.patientData);
    _loadUnreadMessageCount();
  }

  Future<void> _loadUnreadMessageCount() async {
    try {
      final response = await _messageService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadMessageCount = response.unreadCount;
        });
      }
    } catch (e) {
      debugPrint('Failed to load unread message count: $e');
    }
  }

  String _getFullAvatarUrl(String? avatarPath) {
    return ApiConfig.getAvatarUrl(avatarPath);
  }

  Future<void> _refreshData() async {
    // Refresh unread message count
    await _loadUnreadMessageCount();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryGreen,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildAccountSettings(),
                  _buildMessagesSection(),
                  _buildServicesSection(),
                  _buildHelpSection(),
                  _buildLogoutButton(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    // Extract initials from patient name
    String getInitials(String name) {
      List<String> nameParts = name.trim().split(' ');
      if (nameParts.isEmpty) return 'PT';
      if (nameParts.length == 1) return nameParts[0][0].toUpperCase();
      return '${nameParts[0][0]}${nameParts[nameParts.length - 1][0]}'.toUpperCase();
    }

    final avatarPath = _currentPatientData['avatar'];
    final fullAvatarUrl = _getFullAvatarUrl(avatarPath);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primaryGreen,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: fullAvatarUrl.isNotEmpty
                        ? Image.network(
                            fullAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Avatar loading error: $error');
                              print('📸 Avatar path: $avatarPath');
                              print('🔗 Full URL: $fullAvatarUrl');
                              return _buildInitialsAvatar(getInitials(
                                _currentPatientData['name'] ?? 
                                _currentPatientData['full_name'] ?? 
                                'Patient'
                              ));
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildInitialsAvatar(getInitials(
                            _currentPatientData['name'] ?? 
                            _currentPatientData['full_name'] ?? 
                            'Patient'
                          )),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentPatientData['name'] ?? _currentPatientData['full_name'] ?? 'Patient Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentPatientData['email'] ?? 'patient@email.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Valued Patient',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this helper method to build the initials avatar
  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.primaryGreen,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Update your profile details',
            iconColor: const Color(0xFF6C63FF),
            iconBg: const Color(0xFFEDE9FF),
            onTap: () => _navigateToPersonalInfo(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Password & Security',
            subtitle: 'Change password and security settings',
            iconColor: AppColors.primaryGreen,
            iconBg: const Color(0xFFE8F5F5),
            onTap: () => _navigateToPasswordSecurity(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notification Preferences',
            subtitle: 'Manage your notification settings',
            iconColor: const Color(0xFFFF9A00),
            iconBg: const Color(0xFFFFF4E5),
            onTap: () => _navigateToNotificationPreferences(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Communication',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: 'Chat with our care team',
            iconColor: const Color(0xFF2196F3),
            iconBg: const Color(0xFFE3F2FD),
            badge: _unreadMessageCount > 0 ? _unreadMessageCount.toString() : null,
            onTap: () => _navigateToMessages(),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'My Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.local_shipping_outlined,
            title: 'My Transport Requests',
            subtitle: 'View your transportation history',
            iconColor: const Color(0xFF4CAF50),
            iconBg: const Color(0xFFE8F5E9),
            onTap: () => _navigateToTransportRequests(),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.help_outline,
            title: 'FAQ',
            subtitle: 'Find answers to common questions',
            iconColor: const Color(0xFF00BCD4),
            iconBg: const Color(0xFFE0F7FA),
            onTap: () => _navigateToFAQs(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.support_agent_outlined,
            title: 'Help Center',
            subtitle: 'Contact support team',
            iconColor: const Color(0xFFFF9800),
            iconBg: const Color(0xFFFFF3E0),
            onTap: () => _navigateToHelpCenter(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            iconColor: const Color(0xFF607D8B),
            iconBg: const Color(0xFFECEFF1),
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4757),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => _showLogoutDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF4757).withOpacity(0.1),
                const Color(0xFFFF6B7A).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF4757).withOpacity(0.3),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Color(0xFFFF4757),
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4757),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToMessages() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationsScreen(
          userData: _currentPatientData,
        ),
      ),
    );
    // Refresh unread count when returning from messages screen
    _loadUnreadMessageCount();
  }

  void _navigateToTransportRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportRequestScreen(
          userData: _currentPatientData,
        ),
      ),
    );
  }

  void _navigateToFAQs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatientFAQScreen(),
      ),
    );
  }

  void _navigateToHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatientHelpCenterScreen(),
      ),
    );
  }

  // ✅ Updated method to handle profile updates
  Future<void> _navigateToPersonalInfo() async {
    print('🔵 Navigating to Personal Information Screen');
    
    // Navigate and wait for result
    final updatedData = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInformationScreen(
          userData: _currentPatientData,
        ),
      ),
    );

    // ✅ Check if data was returned (user saved changes)
    if (updatedData != null && mounted) {
      print('✅ Received updated profile data');
      print('📦 Updated data: $updatedData');
      
      // Update the current patient data
      setState(() {
        _currentPatientData = updatedData;
      });
      
      print('🔄 Account screen UI refreshed with new profile data');
      print('   New Name: ${_currentPatientData['name']}');
      print('   New Email: ${_currentPatientData['email']}');
    } else {
      print('ℹ️ No profile update (user cancelled or no changes)');
    }
  }

  void _navigateToPasswordSecurity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordSecurityScreen(
          userData: _currentPatientData,
        ),
      ),
    );
  }

  void _navigateToNotificationPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientNotificationPreferencesScreen(
          userData: _currentPatientData,
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: AppColors.primaryGreen),
            SizedBox(width: 12),
            Text('About'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Judy Home HealthCare',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Providing quality home healthcare services with compassion and excellence.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFFF4757)),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleLogout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Proper logout implementation
  Future<void> _handleLogout() async {
    // Close the dialog first
    Navigator.pop(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Signing out...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Call the logout API
      final result = await _authService.logout();
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result['success'] == true) {
        // Clear all navigation stack and go to login
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LoginSignupScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to sign out'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}