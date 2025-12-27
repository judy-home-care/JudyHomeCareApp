import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../utils/app_colors.dart';
import '../../services/auth/auth_service.dart';
import '../nurse/nurse_main_screen.dart';
import '../patient/patient_main_screen.dart';

class TwoFactorLoginScreen extends StatefulWidget {
  final Map<String, dynamic> twoFactorData;
  final String email;
  final String password;
  final bool rememberMe;

  const TwoFactorLoginScreen({
    super.key,
    required this.twoFactorData,
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  @override
  State<TwoFactorLoginScreen> createState() => _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends State<TwoFactorLoginScreen> {
  final _authService = AuthService();
  final _localAuth = LocalAuthentication();
  final _otpController = TextEditingController();
  
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // If biometric, trigger authentication immediately
    if (_isBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBiometricAuth();
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  bool get _isBiometric => widget.twoFactorData['two_factor_method'] == 'biometric';
  bool get _isSMS => widget.twoFactorData['two_factor_method'] == 'sms';
  bool get _isEmail => widget.twoFactorData['two_factor_method'] == 'email';

  String get _maskedContact {
    if (_isSMS) {
      return widget.twoFactorData['data']?['phone'] ?? '***';
    } else if (_isEmail) {
      return widget.twoFactorData['data']?['email'] ?? '***';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Two-Factor Authentication',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isBiometric ? _buildBiometricView() : _buildOtpView(),
    );
  }

  Widget _buildBiometricView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint,
                size: 80,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Biometric Verification',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Verify your identity to continue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            if (_isVerifying)
              const CircularProgressIndicator(
                color: AppColors.primaryGreen,
              )
            else
              ElevatedButton.icon(
                onPressed: _handleBiometricAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.fingerprint),
                label: const Text(
                  'Authenticate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isSMS ? Icons.sms : Icons.email,
              size: 60,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Enter Verification Code',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a 6-digit code to\n$_maskedContact',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 16,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
            ),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
              if (value.length == 6) {
                _verifyOtp();
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Didn\'t receive code? ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              TextButton(
                onPressed: _isResending ? null : _resendCode,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                ),
                child: _isResending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : const Text(
                        'Resend',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBiometricAuth() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to complete login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        // Verify with backend using session token
        final result = await _authService.verifyLoginTwoFactor(
          userId: widget.twoFactorData['data']['user_id'],
          sessionToken: widget.twoFactorData['session_token'],
          rememberMe: widget.rememberMe,
        );

        if (!mounted) return;

        if (result['success']) {
          _handleSuccessfulLogin(result);
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Verification failed';
            _isVerifying = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Authentication failed';
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error: ${e.toString()}';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.verifyLoginTwoFactor(
        userId: widget.twoFactorData['data']['user_id'],
        code: _otpController.text,
        rememberMe: widget.rememberMe,
      );

      if (!mounted) return;

      if (result['success']) {
        _handleSuccessfulLogin(result);
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Invalid code';
          _isVerifying = false;
        });
        _otpController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Verification failed. Please try again.';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final result = await _authService.resendLoginTwoFactor(
        userId: widget.twoFactorData['data']['user_id'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Code sent'),
          backgroundColor: result['success'] 
              ? AppColors.primaryGreen 
              : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to resend code'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _handleSuccessfulLogin(Map<String, dynamic> result) {
    final userData = result['data']['user'];
    final userRole = userData['role'] as String;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome, ${userData['first_name']}!'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // Navigate based on user role
    Widget destination;
    
    switch (userRole) {
      case 'patient':
        destination = PatientMainScreen(
          patientData: {
            'name': userData['full_name'],
            'firstName': userData['first_name'],
            'lastName': userData['last_name'],
            'phone': userData['phone'],
            'gender': userData['gender'],
            'dob': userData['date_of_birth'],
            'avatar': userData['avatar_url'],
            'id': userData['id'].toString(),
            'role': userData['role'],
            'email': userData['email'],
          },
          initialIndex: 0,
        );
        break;
        
      case 'nurse':
        destination = NurseMainScreen(
          nurseData: {
            'name': userData['full_name'],
            'firstName': userData['first_name'],
            'lastName': userData['last_name'],
            'phone': userData['phone'],
            'gender': userData['gender'],
            'dob': userData['date_of_birth'],
            'avatar': userData['avatar_url'],
            'ghanaCardNumber': userData['ghana_card_number'],
            'licenseNumber': userData['license_number'],
            'specialization': userData['specialization'],
            'yearsOfExperience': userData['years_of_experience'],
            'id': userData['id'].toString(),
            'role': userData['role'],
            'email': userData['email'],
          },
          initialIndex: 0,
        );
        break;
        
      default:
        // For other roles, show a message and return
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dashboard for ${userRole}s coming soon!'),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false,
    );
  }
}