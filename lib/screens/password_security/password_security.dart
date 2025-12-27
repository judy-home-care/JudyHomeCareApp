import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../utils/app_colors.dart';
import '../../services/profile_service.dart';

class PasswordSecurityScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ Changed from nurseData to userData
  
  const PasswordSecurityScreen({
    Key? key,
    required this.userData, // ✅ Changed from nurseData to userData
  }) : super(key: key);

  @override
  State<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  final ProfileService _profileService = ProfileService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _twoFactorEnabled = false;
  String? _twoFactorMethod; // 'sms', 'email', 'biometric'
  bool _emailNotifications = true;
  bool _loginAlerts = true;
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  bool _isChangingPassword = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSecuritySettings();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Check if biometric authentication is available
  Future<void> _checkBiometricAvailability() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (canCheckBiometrics && isDeviceSupported) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        
        setState(() {
          _biometricAvailable = true;
          _availableBiometrics = availableBiometrics;
        });
        
        if (kDebugMode) {
          print('✅ Biometric authentication available');
          print('   Available types: $_availableBiometrics');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking biometric availability: $e');
      }
    }
  }

  /// Authenticate using biometrics
  Future<bool> _authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to enable biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      return didAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Biometric authentication error: $e');
      }
      return false;
    }
  }

  String _getBiometricName() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris Scan';
    }
    return 'Biometric';
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    }
    return Icons.security;
  }

  /// Load security settings from backend
  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _profileService.getProfile();
      
      if (result['success'] && result['data'] != null) {
        final data = result['data'];
        
        setState(() {
          _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
          _twoFactorMethod = data['twoFactorMethod'];
          _emailNotifications = data['emailNotifications'] ?? true;
          _loginAlerts = data['loginAlerts'] ?? true;
          _isLoading = false;
        });
        
        if (kDebugMode) {
          print('✅ Loaded security settings:');
          print('   2FA Enabled: $_twoFactorEnabled');
          print('   2FA Method: $_twoFactorMethod');
          print('   Email Notifications: $_emailNotifications');
          print('   Login Alerts: $_loginAlerts');
        }
      } else {
        // Fallback to widget data if API fails
        setState(() {
          _twoFactorEnabled = widget.userData['twoFactorEnabled'] ?? false; // ✅ Changed
          _twoFactorMethod = widget.userData['twoFactorMethod']; // ✅ Changed
          _emailNotifications = widget.userData['emailNotifications'] ?? true; // ✅ Changed
          _loginAlerts = widget.userData['loginAlerts'] ?? true; // ✅ Changed
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading security settings: $e');
      }
      
      // Fallback to widget data
      setState(() {
        _twoFactorEnabled = widget.userData['twoFactorEnabled'] ?? false; // ✅ Changed
        _twoFactorMethod = widget.userData['twoFactorMethod']; // ✅ Changed
        _emailNotifications = widget.userData['emailNotifications'] ?? true; // ✅ Changed
        _loginAlerts = widget.userData['loginAlerts'] ?? true; // ✅ Changed
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Password & Security',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
        : RefreshIndicator(
            onRefresh: _loadSecuritySettings,
            color: AppColors.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSecurityStatusCard(),
                    const SizedBox(height: 24),
                    _buildPasswordSection(),
                    // Only show 2FA and security notifications for non-contact persons
                    if (widget.userData['type'] != 'contact_person') ...[
                      const SizedBox(height: 20),
                      _buildTwoFactorSection(),
                      const SizedBox(height: 20),
                      _buildSecuritySettingsSection(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSecurityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account Security Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _getSecurityLevel(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSecurityLevel() {
    // For contact persons, just show "Good Security" since they only have password
    if (widget.userData['type'] == 'contact_person') {
      return 'Good Security';
    }

    int score = 0;
    if (_twoFactorEnabled) score += 40;
    if (_emailNotifications) score += 30;
    if (_loginAlerts) score += 30;

    if (score >= 80) return 'Excellent Security';
    if (score >= 60) return 'Good Security';
    if (score >= 40) return 'Moderate Security';
    return 'Weak Security';
  }

  Widget _buildPasswordSection() {
    return _buildSection(
      title: 'Change Password',
      icon: Icons.lock_outline,
      iconColor: const Color(0xFF6C63FF),
      iconBg: const Color(0xFFEDE9FF),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildPasswordField(
              controller: _currentPasswordController,
              label: 'Current Password',
              showPassword: _showCurrentPassword,
              onToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              showPassword: _showNewPassword,
              onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              showPassword: _showConfirmPassword,
              onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
            const SizedBox(height: 8),
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6C63FF), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        if (controller == _newPasswordController && value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    String password = _newPasswordController.text;
    int strength = _calculatePasswordStrength(password);
    
    Color strengthColor;
    String strengthText;
    
    if (strength >= 4) {
      strengthColor = const Color(0xFF4CAF50);
      strengthText = 'Strong';
    } else if (strength >= 3) {
      strengthColor = const Color(0xFF2196F3);
      strengthText = 'Good';
    } else if (strength >= 2) {
      strengthColor = const Color(0xFFFF9800);
      strengthText = 'Fair';
    } else {
      strengthColor = const Color(0xFFFF4757);
      strengthText = 'Weak';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              strengthText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < strength ? strengthColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int strength = 0;
    
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    
    return strength;
  }

  Widget _buildTwoFactorSection() {
    return _buildSection(
      title: 'Two-Factor Authentication',
      icon: Icons.security_outlined,
      iconColor: AppColors.primaryGreen,
      iconBg: const Color(0xFFE8F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _twoFactorEnabled 
                ? 'Choose your preferred authentication method:'
                : 'Add an extra layer of security to your account',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // SMS Authentication
          _build2FAOption(
            icon: Icons.sms_outlined,
            title: 'SMS Authentication',
            subtitle: 'Receive verification codes via SMS',
            isActive: _twoFactorEnabled && _twoFactorMethod == 'sms',
            onTap: () => _handle2FAToggle('sms'),
            iconColor: const Color(0xFF2196F3),
          ),
          
          const SizedBox(height: 12),
          
          // Email Authentication
          _build2FAOption(
            icon: Icons.email_outlined,
            title: 'Email Authentication',
            subtitle: 'Receive verification codes via email',
            isActive: _twoFactorEnabled && _twoFactorMethod == 'email',
            onTap: () => _handle2FAToggle('email'),
            iconColor: const Color(0xFFFF9800),
          ),
          
          if (_biometricAvailable) ...[
            const SizedBox(height: 12),
            
            // Biometric Authentication
            _build2FAOption(
              icon: _getBiometricIcon(),
              title: '${_getBiometricName()} Authentication',
              subtitle: 'Use ${_getBiometricName()} to verify your identity',
              isActive: _twoFactorEnabled && _twoFactorMethod == 'biometric',
              onTap: () => _handle2FAToggle('biometric'),
              iconColor: const Color(0xFF9C27B0),
            ),
          ],
          
          if (_twoFactorEnabled && _twoFactorMethod != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _get2FAMethodTitle(_twoFactorMethod!),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _get2FAMethodSubtitle(_twoFactorMethod!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _disableTwoFactor,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                    ),
                    child: const Text('Disable'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _build2FAOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive 
              ? iconColor.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? iconColor
                : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive 
                          ? iconColor
                          : const Color(0xFF1A1A1A),
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
            if (isActive)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey.shade400,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  String _get2FAMethodTitle(String method) {
    switch (method) {
      case 'sms':
        return 'SMS Authentication Active';
      case 'email':
        return 'Email Authentication Active';
      case 'biometric':
        return '${_getBiometricName()} Authentication Active';
      default:
        return '2FA Active';
    }
  }

  String _get2FAMethodSubtitle(String method) {
    switch (method) {
      case 'sms':
        final phone = widget.userData['phone']; // ✅ Changed
        return phone != null && phone.length >= 3
            ? 'Phone: +233 *** *** ${phone.substring(phone.length - 3)}'
            : 'SMS verification enabled';
      case 'email':
        final email = widget.userData['email'] ?? ''; // ✅ Changed
        if (email.contains('@')) {
          final parts = email.split('@');
          return 'Email: ${parts[0].substring(0, 2)}***@${parts[1]}';
        }
        return 'Email verification enabled';
      case 'biometric':
        return '${_getBiometricName()} verification enabled';
      default:
        return 'Two-factor authentication enabled';
    }
  }

  Widget _buildSecuritySettingsSection() {
    return _buildSection(
      title: 'Security Notifications',
      icon: Icons.notifications_outlined,
      iconColor: const Color(0xFFFF9800),
      iconBg: const Color(0xFFFFF3E0),
      child: Column(
        children: [
          _buildSecurityToggle(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Get security alerts via email',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
              _updateNotificationSettings();
            },
            iconColor: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 16),
          _buildSecurityToggle(
            icon: Icons.login,
            title: 'Login Alerts',
            subtitle: 'Alert on new device logins',
            value: _loginAlerts,
            onChanged: (value) {
              setState(() => _loginAlerts = value);
              _updateNotificationSettings();
            },
            iconColor: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget child,
  }) {
    return Container(
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
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
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: iconColor,
        ),
      ],
    );
  }

  void _handle2FAToggle(String method) async {
    // If trying to enable the same method that's already active, do nothing
    if (_twoFactorEnabled && _twoFactorMethod == method) {
      return;
    }

    // If enabling biometric, require authentication first
    if (method == 'biometric') {
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        _showErrorMessage('Biometric authentication failed');
        return;
      }
    }

    // Show confirmation dialog
    _showEnable2FADialog(method);
  }

  void _showEnable2FADialog(String method) {
    String methodTitle;
    String methodDescription;
    IconData methodIcon;
    Color methodColor;

    switch (method) {
      case 'sms':
        methodTitle = 'SMS Authentication';
        methodDescription = 'You will receive a verification code via SMS';
        methodIcon = Icons.sms;
        methodColor = const Color(0xFF2196F3);
        break;
      case 'email':
        methodTitle = 'Email Authentication';
        methodDescription = 'You will receive a verification code via email';
        methodIcon = Icons.email;
        methodColor = const Color(0xFFFF9800);
        break;
      case 'biometric':
        methodTitle = '${_getBiometricName()} Authentication';
        methodDescription = 'You will use ${_getBiometricName()} to verify your identity';
        methodIcon = _getBiometricIcon();
        methodColor = const Color(0xFF9C27B0);
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Row(
          children: [
            Icon(methodIcon, color: methodColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable $methodTitle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          methodDescription,
          style: const TextStyle(
            height: 1.5,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enableTwoFactor(method);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: methodColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _enableTwoFactor(String method) async {
    try {
      final result = await _profileService.enableTwoFactor(method: method);
      
      if (mounted) {
        if (result['success']) {
          // For biometric, 2FA is enabled immediately
          if (method == 'biometric') {
            setState(() {
              _twoFactorEnabled = true;
              _twoFactorMethod = method;
            });
            _showSuccessMessage(result['message']);
          } else {
            // For SMS and Email, show OTP verification dialog
            _showOtpVerificationDialog(method, result['data']);
          }
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to enable two-factor authentication');
      }
    }
  }

  void _showOtpVerificationDialog(String method, Map<String, dynamic>? data) {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;
    
    String methodTitle = method == 'sms' ? 'Phone' : 'Email';
    String maskedContact = method == 'sms' 
        ? (data?['phone'] ?? '***')
        : (data?['email'] ?? '***');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  method == 'sms' ? Icons.sms : Icons.email,
                  color: AppColors.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We sent a 6-digit code to\n$maskedContact',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive code? ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  TextButton(
                    onPressed: isVerifying ? null : () => _resendTwoFactorCode(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Resend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (otpController.text.length != 6) {
                        _showErrorMessage('Please enter a 6-digit code');
                        return;
                      }

                      setDialogState(() => isVerifying = true);

                      try {
                        final result = await _profileService.verifyTwoFactorOtp(
                          otp: otpController.text,
                        );

                        if (mounted) {
                          if (result['success']) {
                            Navigator.pop(dialogContext);
                            setState(() {
                              _twoFactorEnabled = true;
                              _twoFactorMethod = method;
                            });
                            _showSuccessMessage(result['message']);
                          } else {
                            setDialogState(() => isVerifying = false);
                            _showErrorMessage(result['message']);
                            otpController.clear();
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isVerifying = false);
                        _showErrorMessage('Failed to verify code');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  void _resendTwoFactorCode() async {
    try {
      final result = await _profileService.resendTwoFactorCode();
      
      if (mounted) {
        if (result['success']) {
          _showSuccessMessage(result['message']);
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to resend code');
      }
    }
  }

  void _disableTwoFactor() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Disable 2FA'),
          ],
        ),
        content: const Text(
          'Are you sure you want to disable two-factor authentication? This will make your account less secure.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _profileService.disableTwoFactor();
      
      if (mounted) {
        if (result['success']) {
          setState(() {
            _twoFactorEnabled = false;
            _twoFactorMethod = null;
          });
          _showSuccessMessage(result['message']);
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to disable two-factor authentication');
      }
    }
  }

  void _updateNotificationSettings() async {
    try {
      final result = await _profileService.updateNotificationSettings(
        emailNotifications: _emailNotifications,
        loginAlerts: _loginAlerts,
      );
      
      if (mounted) {
        if (result['success']) {
          _showSuccessMessage(result['message']);
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to update notification settings');
      }
    }
  }

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorMessage('New passwords do not match');
      return;
    }

    if (_newPasswordController.text == _currentPasswordController.text) {
      _showErrorMessage('New password must be different from current password');
      return;
    }
    
    setState(() => _isChangingPassword = true);
    
    try {
      final result = await _profileService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        newPasswordConfirmation: _confirmPasswordController.text,
      );
      
      setState(() => _isChangingPassword = false);
      
      if (mounted) {
        if (result['success']) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          
          _showSuccessMessage(result['message']);
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      setState(() => _isChangingPassword = false);
      
      if (mounted) {
        _showErrorMessage('An error occurred while changing password');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}