import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../services/auth/forgot_password_service.dart';
import '../../models/auth/forgot_password_models.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Pre-calculated colors
  static const Color _primaryColor = Color(0xFF199A8E);
  static const Color _primaryLight = Color(0x14199A8E); // ~8% opacity
  static const Color _primaryLighter = Color(0x0A199A8E); // ~4% opacity
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF666666);
  static const Color _borderGrey = Color(0xFFE5E5E5);
  static const Color _backgroundGrey = Color(0xFFF8FAFB);
  
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Service
  final _forgotPasswordService = ForgotPasswordService();

  // OTP controllers
  late List<TextEditingController> _otpBoxControllers;
  late List<FocusNode> _otpFocusNodes;

  // State variables
  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isVerifying = false;
  bool _isOtpVerified = false;
  bool _isResetting = false;
  int _resendCountdown = 0;
  bool _isResetComplete = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _resetToken;

  // Country selection
  String _selectedCountryCode = '+233';
  String _selectedCountryFlag = '🇬🇭';

  final List<Map<String, String>> _countries = [
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeOtpControllers();
  }

  void _initializeOtpControllers() {
    _otpBoxControllers = List.generate(6, (index) => TextEditingController());
    _otpFocusNodes = List.generate(6, (index) => FocusNode());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    for (var controller in _otpBoxControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundGrey,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isResetComplete) {
      return _buildSuccessView();
    } else if (_isOtpVerified) {
      return _buildResetPasswordView();
    } else if (_isOtpSent) {
      return _buildOtpVerificationView();
    } else {
      return _buildContactInputView();
    }
  }

  Widget _buildContactInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const _Header(),
          const SizedBox(height: 50),
          _SimplifiedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WelcomeSection(),
                const SizedBox(height: 30),
                _PhoneField(
                  controller: _phoneController,
                  selectedCountryCode: _selectedCountryCode,
                  selectedCountryFlag: _selectedCountryFlag,
                  onCountryTap: _showCountryPicker,
                ),
                const SizedBox(height: 30),
                _SimplifiedButton(
                  label: 'Send Code',
                  icon: Icons.send_rounded,
                  isLoading: _isLoading,
                  onPressed: _handleSendCode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _BottomLink(),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const _Header(),
          const SizedBox(height: 50),
          _SimplifiedCard(
            child: Column(
              children: [
                _OtpHeader(
                  phone: '$_selectedCountryCode${_phoneController.text}',
                ),
                const SizedBox(height: 40),
                _OtpInputBoxes(
                  controllers: _otpBoxControllers,
                  focusNodes: _otpFocusNodes,
                  onChanged: (index, value) {
                    setState(() {});
                    if (value.isNotEmpty) {
                      if (index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else {
                        _otpFocusNodes[index].unfocus();
                      }
                    }
                    _updateOtpValue();
                  },
                ),
                const SizedBox(height: 30),
                _SimplifiedButton(
                  label: 'Verify & Continue',
                  isLoading: _isVerifying,
                  onPressed: _handleVerifyCode,
                ),
                const SizedBox(height: 20),
                _ResendSection(
                  countdown: _resendCountdown,
                  onResend: _handleResendCode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const _Header(),
          const SizedBox(height: 50),
          _SimplifiedCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ResetPasswordHeader(),
                  const SizedBox(height: 30),
                  _PasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    hint: 'Enter your new password',
                    isVisible: _isNewPasswordVisible,
                    onToggle: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                  ),
                  const SizedBox(height: 20),
                  _PasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Re-enter your new password',
                    isVisible: _isConfirmPasswordVisible,
                    onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _PasswordStrengthIndicator(
                    password: _newPasswordController.text,
                  ),
                  const SizedBox(height: 30),
                  _SimplifiedButton(
                    label: 'Reset Password',
                    icon: Icons.check_circle_outline,
                    isLoading: _isResetting,
                    onPressed: _handleResetPassword,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const _SuccessIcon(),
            const SizedBox(height: 40),
            const Text(
              'Password Changed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your password has been successfully reset',
              style: TextStyle(
                fontSize: 16,
                color: _textGrey,
              ),
            ),
            const SizedBox(height: 40),
            _SimplifiedButton(
              label: 'Back to Login',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => 
                        const LoginScreen(),
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateOtpValue() {
    String otp = '';
    for (var controller in _otpBoxControllers) {
      otp += controller.text;
    }
    _otpController.text = otp;
    
    if (otp.length == 6 && !_isVerifying) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _otpController.text.length == 6) {
          _handleVerifyCode();
        }
      });
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      builder: (context) => _CountryPicker(
        countries: _countries,
        onCountrySelected: (code, flag) {
          setState(() {
            _selectedCountryCode = code;
            _selectedCountryFlag = flag;
          });
        },
      ),
    );
  }

  // API HANDLERS
  void _handleSendCode() async {
    if (_phoneController.text.trim().isEmpty) {
      _showErrorMessage('Please enter your phone number');
      return;
    }
    if (!_forgotPasswordService.isValidPhone(_phoneController.text.trim())) {
      _showErrorMessage('Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phone = _forgotPasswordService.formatPhoneNumber(
        _phoneController.text.trim(),
        _selectedCountryCode,
      );

      final request = ForgotPasswordRequest(phone: phone);
      final response = await _forgotPasswordService.sendResetCode(request);

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _isOtpSent = true;
        });
        _startResendCountdown();
        _showSuccessMessage(response.message);
      } else {
        _showErrorMessage(response.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleVerifyCode() async {
    if (_otpController.text.length != 6) {
      _showErrorMessage('Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final phone = _forgotPasswordService.formatPhoneNumber(
        _phoneController.text.trim(),
        _selectedCountryCode,
      );

      final request = VerifyOtpRequest(
        phone: phone,
        otp: _otpController.text,
      );

      final response = await _forgotPasswordService.verifyOtp(request);

      if (!mounted) return;

      if (response.success && response.data != null) {
        _resetToken = response.data!.resetToken;

        setState(() {
          _isOtpVerified = true;
        });
        _showSuccessMessage('Code verified successfully!');
      } else {
        _showErrorMessage(response.message);
        for (var controller in _otpBoxControllers) {
          controller.clear();
        }
        _otpController.clear();
        if (_otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to verify code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _handleResendCode() async {
    try {
      final phone = _forgotPasswordService.formatPhoneNumber(
        _phoneController.text.trim(),
        _selectedCountryCode,
      );

      final request = ResendOtpRequest(phone: phone);
      final response = await _forgotPasswordService.resendOtp(request);

      if (mounted) {
        if (response.success) {
          _showSuccessMessage(response.message);
          _startResendCountdown();

          for (var controller in _otpBoxControllers) {
            controller.clear();
          }
          _otpController.clear();
          if (_otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        } else {
          _showErrorMessage(response.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to resend code. Please try again.');
      }
    }
  }

  void _handleResetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isResetting = true;
      });

      try {
        final phone = _forgotPasswordService.formatPhoneNumber(
          _phoneController.text.trim(),
          _selectedCountryCode,
        );

        if (_resetToken == null || _resetToken!.isEmpty) {
          _showErrorMessage('Session expired. Please verify code again.');
          setState(() {
            _isOtpVerified = false;
            _isResetting = false;
          });
          return;
        }

        final request = ResetPasswordRequest(
          phone: phone,
          token: _resetToken!,
          password: _newPasswordController.text,
          passwordConfirmation: _confirmPasswordController.text,
        );

        final response = await _forgotPasswordService.resetPassword(request);

        if (!mounted) return;

        if (response.success) {
          setState(() {
            _isResetComplete = true;
          });
          _showSuccessMessage(response.message);
        } else {
          _showErrorMessage(response.message);
        }
      } catch (e) {
        if (mounted) {
          _showErrorMessage('Failed to reset password. Please try again.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isResetting = false;
          });
        }
      }
    }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 30;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// Simplified reusable widgets

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _ForgotPasswordScreenState._borderGrey,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: _ForgotPasswordScreenState._textDark,
              size: 20,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _ForgotPasswordScreenState._primaryLighter,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _ForgotPasswordScreenState._primaryLight,
              width: 1,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.verified_user,
                size: 16,
                color: _ForgotPasswordScreenState._primaryColor,
              ),
              SizedBox(width: 6),
              Text(
                'Secure Reset',
                style: TextStyle(
                  fontSize: 12,
                  color: _ForgotPasswordScreenState._primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SimplifiedCard extends StatelessWidget {
  final Widget child;
  
  const _SimplifiedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _ForgotPasswordScreenState._borderGrey,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: _ForgotPasswordScreenState._textDark,
            letterSpacing: -1,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Enter your registered phone number to receive a verification code via SMS',
          style: TextStyle(
            fontSize: 15,
            color: _ForgotPasswordScreenState._textGrey,
            letterSpacing: -0.2,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ContactMethodToggle extends StatelessWidget {
  final String contactMethod;
  final Function(String) onMethodChanged;

  const _ContactMethodToggle({
    required this.contactMethod,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _ForgotPasswordScreenState._borderGrey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onMethodChanged('email'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: contactMethod == 'email'
                      ? _ForgotPasswordScreenState._primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_rounded,
                      color: contactMethod == 'email'
                          ? Colors.white
                          : const Color(0xFF9E9E9E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Email',
                      style: TextStyle(
                        color: contactMethod == 'email'
                            ? Colors.white
                            : const Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => onMethodChanged('phone'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: contactMethod == 'phone'
                      ? _ForgotPasswordScreenState._primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      color: contactMethod == 'phone'
                          ? Colors.white
                          : const Color(0xFF9E9E9E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phone',
                      style: TextStyle(
                        color: contactMethod == 'phone'
                            ? Colors.white
                            : const Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;

  const _EmailField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('email'),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ForgotPasswordScreenState._textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Enter your email address',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _ForgotPasswordScreenState._primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: _ForgotPasswordScreenState._primaryColor,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _ForgotPasswordScreenState._borderGrey,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _ForgotPasswordScreenState._borderGrey,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _ForgotPasswordScreenState._primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCountryCode;
  final String selectedCountryFlag;
  final VoidCallback onCountryTap;

  const _PhoneField({
    required this.controller,
    required this.selectedCountryCode,
    required this.selectedCountryFlag,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('phone'),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCountryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _ForgotPasswordScreenState._borderGrey,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    selectedCountryFlag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedCountryCode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
                _NoLeadingZeroFormatter(),
              ],
              decoration: InputDecoration(
                hintText: '24 XXX XXXX',
                hintStyle: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _ForgotPasswordScreenState._borderGrey,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _ForgotPasswordScreenState._borderGrey,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _ForgotPasswordScreenState._primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isVisible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isVisible,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ForgotPasswordScreenState._textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator ?? (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
          style: const TextStyle(
            fontSize: 15,
            color: _ForgotPasswordScreenState._textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _ForgotPasswordScreenState._primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: _ForgotPasswordScreenState._primaryColor,
                ),
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF9E9E9E),
                size: 20,
              ),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _ForgotPasswordScreenState._borderGrey,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _ForgotPasswordScreenState._borderGrey,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _ForgotPasswordScreenState._primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _OtpHeader extends StatelessWidget {
  final String phone;

  const _OtpHeader({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _ForgotPasswordScreenState._primaryLighter,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sms_rounded,
            size: 40,
            color: _ForgotPasswordScreenState._primaryColor,
          ),
        ),
        const SizedBox(height: 20),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _ForgotPasswordScreenState._textDark,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code via SMS to\n$phone',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: _ForgotPasswordScreenState._textGrey,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _OtpInputBoxes extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Function(int, String) onChanged;

  const _OtpInputBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive box size based on available width
        // Account for spacing between boxes
        final availableWidth = constraints.maxWidth;
        final spacing = 8.0; // Space between boxes
        final totalSpacing = spacing * 5; // 5 gaps between 6 boxes
        final boxWidth = (availableWidth - totalSpacing) / 6;
        
        // Ensure minimum readability - cap at 45px width minimum
        final finalBoxWidth = boxWidth.clamp(40.0, 52.0);
        final finalBoxHeight = finalBoxWidth + 8; // Slightly taller than wide
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Changed from spaceEvenly
          children: List.generate(6, (index) {
            return Container(
              width: finalBoxWidth,
              height: finalBoxHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: controllers[index].text.isNotEmpty
                      ? _ForgotPasswordScreenState._primaryColor
                      : _ForgotPasswordScreenState._borderGrey,
                  width: controllers[index].text.isNotEmpty ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: TextFormField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  obscureText: false,
                  showCursor: true,
                  cursorColor: _ForgotPasswordScreenState._primaryColor,
                  cursorHeight: 20,
                  style: TextStyle(
                    fontSize: finalBoxWidth * 0.44, // Responsive font size
                    fontWeight: FontWeight.bold,
                    color: _ForgotPasswordScreenState._textDark,
                    height: 1.2,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1),
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '•',
                    hintStyle: TextStyle(
                      fontSize: finalBoxWidth * 0.56, // Responsive hint size
                      color: const Color(0xFFE0E0E0),
                      fontWeight: FontWeight.w300,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => onChanged(index, value),
                  onTap: () {
                    controllers[index].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controllers[index].text.length,
                    );
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ResetPasswordHeader extends StatelessWidget {
  const _ResetPasswordHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _ForgotPasswordScreenState._primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 24,
            color: _ForgotPasswordScreenState._primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Create New Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _ForgotPasswordScreenState._textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be different from previous ones',
          style: TextStyle(
            fontSize: 14,
            color: _ForgotPasswordScreenState._textGrey,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    int strength = 0;
    String strengthText = 'Enter password';
    Color strengthColor = const Color(0xFF9E9E9E);
    
    if (password.isNotEmpty) {
      if (password.length >= 8) strength++;
      if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
      if (RegExp(r'[0-9]').hasMatch(password)) strength++;
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
      
      switch (strength) {
        case 1:
          strengthText = 'Weak';
          strengthColor = Colors.red;
          break;
        case 2:
          strengthText = 'Fair';
          strengthColor = Colors.orange;
          break;
        case 3:
          strengthText = 'Good';
          strengthColor = Colors.blue;
          break;
        case 4:
          strengthText = 'Strong';
          strengthColor = _ForgotPasswordScreenState._primaryColor;
          break;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 13,
                color: _ForgotPasswordScreenState._textGrey,
              ),
            ),
            Text(
              strengthText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < strength ? strengthColor : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SimplifiedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SimplifiedButton({
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _ForgotPasswordScreenState._primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: _ForgotPasswordScreenState._primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ResendSection extends StatelessWidget {
  final int countdown;
  final VoidCallback onResend;

  const _ResendSection({
    required this.countdown,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't receive code? ",
          style: TextStyle(
            color: _ForgotPasswordScreenState._textGrey,
            fontSize: 14,
          ),
        ),
        if (countdown > 0)
          Text(
            'Resend in ${countdown}s',
            style: const TextStyle(
              color: _ForgotPasswordScreenState._primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          )
        else
          GestureDetector(
            onTap: onResend,
            child: const Text(
              'Resend Code',
              style: TextStyle(
                color: _ForgotPasswordScreenState._primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomLink extends StatelessWidget {
  const _BottomLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Remember your password? ',
            style: TextStyle(
              fontSize: 14,
              color: _ForgotPasswordScreenState._textGrey,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ForgotPasswordScreenState._primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: _ForgotPasswordScreenState._primaryLight,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle_rounded,
        size: 60,
        color: _ForgotPasswordScreenState._primaryColor,
      ),
    );
  }
}

class _CountryPicker extends StatelessWidget {
  final List<Map<String, String>> countries;
  final Function(String, String) onCountrySelected;

  const _CountryPicker({
    required this.countries,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Select Country',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final country = countries[index];
              return ListTile(
                leading: Text(
                  country['flag']!,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(country['name']!),
                trailing: Text(
                  country['code']!,
                  style: const TextStyle(
                    color: _ForgotPasswordScreenState._textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  onCountrySelected(country['code']!, country['flag']!);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Custom TextInputFormatter that prevents "0" as the first character
class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value starts with "0", reject the change
    if (newValue.text.isNotEmpty && newValue.text.startsWith('0')) {
      return oldValue;
    }
    return newValue;
  }
}