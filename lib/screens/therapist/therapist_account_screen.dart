import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/api_config.dart';
import '../../services/auth/auth_service.dart';
import '../profile/profile_screen.dart';
import '../password_security/password_security.dart';
import '../nurse/nurse_notification_preferences.dart';
import '../nurse/nurse_faq_screen.dart';
import '../help_center.dart';
import '../onboarding/login_signup_screen.dart';

/// Account screen for physiotherapists / speech therapists.
/// Mirrors the nurse account screen but without nurse-only items
/// (time logs, transport, clock-in) and with the therapist discipline badge.
class TherapistAccountScreen extends StatefulWidget {
  final Map<String, dynamic> therapistData;

  const TherapistAccountScreen({
    Key? key,
    required this.therapistData,
  }) : super(key: key);

  @override
  State<TherapistAccountScreen> createState() => _TherapistAccountScreenState();
}

class _TherapistAccountScreenState extends State<TherapistAccountScreen>
    with AutomaticKeepAliveClientMixin {
  final _authService = AuthService();
  late Map<String, dynamic> _currentData;

  @override
  bool get wantKeepAlive => true;

  String get _role => (_currentData['role'] ?? 'physiotherapist').toString();
  bool get _isSpeech => _role == 'speech_therapist';
  String get _roleLabel => _isSpeech ? 'Speech Therapist' : 'Physiotherapist';
  IconData get _roleIcon => _isSpeech ? Icons.record_voice_over_outlined : Icons.accessibility_new_rounded;

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.therapistData);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'TH';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfessionalCard(),
                _buildAccountSettings(),
                _buildHelpSection(),
                _buildLogoutButton(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final avatarPath = _currentData['avatar'] ?? _currentData['avatar_url'];
    final fullAvatarUrl = ApiConfig.getAvatarUrl(avatarPath?.toString());
    final name = (_currentData['name'] ?? _currentData['full_name'] ?? 'Therapist').toString();

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
                            errorBuilder: (_, __, ___) => _buildInitialsAvatar(_initials(name)),
                          )
                        : _buildInitialsAvatar(_initials(name)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (_currentData['email'] ?? '').toString(),
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_roleIcon, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Verified $_roleLabel',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.primaryGreen,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProfessionalCard() {
    final specialization = _currentData['specialization']?.toString();
    final license = _currentData['licenseNumber']?.toString() ?? _currentData['license_number']?.toString();
    final years = _currentData['yearsOfExperience'] ?? _currentData['years_of_experience'];

    String pretty(String? v) => (v == null || v.isEmpty)
        ? 'Not set'
        : v.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.badge_outlined, 'Discipline', _roleLabel),
          _buildInfoRow(Icons.star_outline, 'Specialization', pretty(specialization)),
          _buildInfoRow(Icons.verified_outlined, 'License', (license == null || license.isEmpty) ? 'Not set' : license),
          _buildInfoRow(Icons.work_outline, 'Experience', years == null ? 'Not set' : '$years year${years == 1 ? '' : 's'}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          // Fixed label column so every value starts at the same x and is
          // right-aligned to the same edge.
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings() {
    return _buildSection(
      title: 'Account Settings',
      children: [
        _buildSettingTile(
          icon: Icons.person_outline,
          title: 'Personal Information',
          subtitle: 'Update your profile details',
          iconColor: const Color(0xFF6C63FF),
          iconBg: const Color(0xFFEDE9FF),
          onTap: _navigateToPersonalInfo,
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.lock_outline,
          title: 'Password & Security',
          subtitle: 'Change password and security settings',
          iconColor: AppColors.primaryGreen,
          iconBg: const Color(0xFFE8F5F5),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PasswordSecurityScreen(userData: _currentData)),
          ),
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.notifications_outlined,
          title: 'Notification Preferences',
          subtitle: 'Manage your notification settings',
          iconColor: const Color(0xFFFF9A00),
          iconBg: const Color(0xFFFFF4E5),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationPreferencesScreen(userData: _currentData)),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return _buildSection(
      title: 'Help & Support',
      children: [
        _buildSettingTile(
          icon: Icons.help_outline,
          title: 'FAQ',
          subtitle: 'Find answers to common questions',
          iconColor: const Color(0xFF00BCD4),
          iconBg: const Color(0xFFE0F7FA),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NurseFAQScreen())),
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.support_agent_outlined,
          title: 'Help Center',
          subtitle: 'Contact support team',
          iconColor: const Color(0xFFFF9800),
          iconBg: const Color(0xFFFFF3E0),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NurseHelpCenterScreen())),
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version and information',
          iconColor: const Color(0xFF607D8B),
          iconBg: const Color(0xFFECEFF1),
          onTap: _showAboutDialog,
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 0.5),
            ),
          ),
          ...children,
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
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: _showLogoutDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFF4757).withOpacity(0.1), const Color(0xFFFF6B7A).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Color(0xFFFF4757), size: 22),
              SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFF4757), letterSpacing: -0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToPersonalInfo() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => PersonalInformationScreen(userData: _currentData)),
    );
    if (updated != null && mounted) {
      setState(() => _currentData = {..._currentData, ...updated});
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Judy Home HealthCare',
      applicationIcon: const Icon(Icons.health_and_safety, color: AppColors.primaryGreen, size: 40),
      children: [
        Text('Signed in as $_roleLabel.', style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFFF4757)),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: Colors.grey.shade700, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen)),
      ),
    );

    try {
      final result = await _authService.logout();
      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginSignupScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to sign out'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign out. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }
}
