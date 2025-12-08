import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../services/auth/auth_service.dart';
import '../../models/auth/auth_models.dart';
import 'forgot_password_screen.dart';
import '../nurse/nurse_dashboard_screen.dart';
import '../patient/patient_dashboard_screen.dart';
import 'sign_up_screen.dart';
import '../nurse/nurse_main_screen.dart';
import '../patient/patient_main_screen.dart';
import 'two_factor_login_screen.dart';
import '../onboarding/login_signup_screen.dart';
import '../onboarding/get_started_screen.dart';

// CRITICAL: Cache regex patterns as static constants
class _ValidationPatterns {
  static final phoneRegex = RegExp(r'^\d{9,10}$');
  _ValidationPatterns._();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _primaryColor = Color(0xFF199A8E);
  static const Color _primaryLight = Color(0x14199A8E);
  static const Color _primaryLighter = Color(0x0A199A8E);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF666666);
  static const Color _borderGrey = Color(0xFFE5E5E5);
  static const Color _backgroundGrey = Color(0xFFF8FAFB);

  static final _inputBorderRadius = BorderRadius.circular(16);
  static final _buttonBorderRadius = BorderRadius.circular(16);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Country code selection
  String _selectedCountryCode = '+233';
  String _selectedCountryFlag = '🇬🇭';

  final List<Map<String, String>> _countries = [
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    final topSpacing = screenHeight > 700 ? 40.0 : 20.0;
    final headerSpacing = screenHeight > 700 ? 50.0 : 30.0;
    final formSpacing = screenHeight > 700 ? 40.0 : 24.0;
    final signUpSpacing = screenHeight > 700 ? 30.0 : 20.0;
    final bottomSpacing = screenHeight > 700 ? 30.0 : 16.0;

    return Scaffold(
      backgroundColor: _backgroundGrey,
      resizeToAvoidBottomInset: true,
      extendBody: false,
      body: SafeArea(
        maintainBottomViewPadding: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = mediaQuery.viewInsets.bottom;

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        top: 0,
                        bottom: bottomInset > 0 ? 16 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: topSpacing),
                          const _Header(),
                          SizedBox(height: headerSpacing),
                          const _WelcomeSection(),
                          SizedBox(height: formSpacing),
                          RepaintBoundary(
                            child: _LoginForm(
                              formKey: _formKey,
                              phoneController: _phoneController,
                              passwordController: _passwordController,
                              isPasswordVisible: _isPasswordVisible,
                              rememberMe: _rememberMe,
                              isLoading: _isLoading,
                              selectedCountryCode: _selectedCountryCode,
                              selectedCountryFlag: _selectedCountryFlag,
                              onCountryPickerTap: _showCountryPicker,
                              onPasswordVisibilityToggle: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              onRememberMeToggle: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              onLogin: _handleLogin,
                            ),
                          ),
                          SizedBox(height: signUpSpacing),
                          const _SignUpLink(),
                          SizedBox(height: bottomSpacing),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      FocusScope.of(context).unfocus();

      try {
        final fullPhone = '$_selectedCountryCode${_phoneController.text.trim()}';

        final loginRequest = LoginRequest(
          phone: fullPhone,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );

        if (kDebugMode) {
          print('🔵 Starting login process with phone: $fullPhone');
        }

        final response = await _authService.login(loginRequest);

        if (!mounted) return;

        if (kDebugMode) {
          print('🟢 Login response received');
          print('   Success: ${response.success}');
          print('   Requires 2FA: ${response.requires2FA}');
          print('   Has data: ${response.data != null}');
          print('   Has 2FA data: ${response.twoFactorData != null}');
        }

        if (response.success) {
          if (response.requires2FA == true && response.twoFactorData != null) {
            if (kDebugMode) {
              print('✅ 2FA required - navigating to verification screen');
              print('   Method: ${response.twoFactorData!['two_factor_method']}');
            }
            _handle2FARequired(response, fullPhone);
          } else if (response.data != null) {
            if (kDebugMode) {
              print('✅ Normal login - navigating to dashboard');
            }
            _handleSuccessfulLogin(response.data!);
          } else {
            if (kDebugMode) {
              print('❌ Success but no data or 2FA info');
            }
            _showErrorMessage('Login failed. Please try again.');
          }
        } else {
          if (kDebugMode) {
            print('❌ Login failed: ${response.message}');
          }
          _showErrorMessage(response.message);
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('❌ Login exception: $e');
          print('Stack trace: $stackTrace');
        }
        if (mounted) {
          _showErrorMessage('An error occurred: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handle2FARequired(LoginResponse response, String phone) {
    if (kDebugMode) {
      print('🔵 Navigating to 2FA screen with data: ${response.twoFactorData}');
    }

    setState(() {
      _isLoading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TwoFactorLoginScreen(
          twoFactorData: response.twoFactorData!,
          email: phone, // Using phone as identifier
          password: _passwordController.text,
          rememberMe: _rememberMe,
        ),
      ),
    );
  }

  void _handleSuccessfulLogin(LoginData loginData) {
    final user = loginData.user;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome back, ${user.firstName}!'),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    switch (user.role) {
      case 'nurse':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => NurseMainScreen(
              nurseData: {
                'name': user.fullName,
                'firstName': user.firstName,
                'lastName': user.lastName,
                'phone': user.phone,
                'gender': user.gender,
                'dob': user.dateOfBirth,
                'avatar': user.avatarUrl,
                'ghanaCardNumber': user.ghanaCardNumber,
                'licenseNumber': user.licenseNumber,
                'specialization': user.specialization,
                'yearsOfExperience': user.yearsOfExperience,
                'id': user.id.toString(),
                'role': user.role,
                'email': user.email
              },
              initialIndex: 0,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;

      case 'patient':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PatientMainScreen(
              patientData: {
                'name': user.fullName,
                'firstName': user.firstName,
                'lastName': user.lastName,
                'phone': user.phone,
                'gender': user.gender,
                'dob': user.dateOfBirth,
                'avatar': user.avatarUrl,
                'id': user.id.toString(),
                'role': user.role,
                'emergency_contact_notify': user.emergencyContactNotify,
                'email': user.email
              },
              initialIndex: 0,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;

      case 'doctor':
        _showInfoMessage('Doctor dashboard coming soon!');
        break;

      case 'admin':
      case 'superadmin':
        _showInfoMessage('Admin dashboard coming soon!');
        break;

      default:
        _showErrorMessage('Invalid user role.');
    }
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

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LoginSignupScreen(),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _LoginScreenState._borderGrey,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: _LoginScreenState._textDark,
                  size: 20,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _LoginScreenState._primaryLighter,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: _LoginScreenState._primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  'Secure Login',
                  style: TextStyle(
                    fontSize: 12,
                    color: _LoginScreenState._primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          'Welcome back',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: _LoginScreenState._textDark,
            letterSpacing: -1,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sign in to continue your healthcare journey',
          style: TextStyle(
            fontSize: 15,
            color: _LoginScreenState._textGrey,
            letterSpacing: -0.2,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool rememberMe;
  final bool isLoading;
  final String selectedCountryCode;
  final String selectedCountryFlag;
  final VoidCallback onCountryPickerTap;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onRememberMeToggle;
  final Future<void> Function() onLogin;

  const _LoginForm({
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.rememberMe,
    required this.isLoading,
    required this.selectedCountryCode,
    required this.selectedCountryFlag,
    required this.onCountryPickerTap,
    required this.onPasswordVisibilityToggle,
    required this.onRememberMeToggle,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Number Field with Country Code
          _PhoneTextField(
            controller: phoneController,
            selectedCountryCode: selectedCountryCode,
            selectedCountryFlag: selectedCountryFlag,
            onCountryPickerTap: onCountryPickerTap,
          ),
          const SizedBox(height: 20),
          _OptimizedTextField(
            controller: passwordController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscureText: !isPasswordVisible,
            isPassword: true,
            onToggleVisibility: onPasswordVisibilityToggle,
            isPasswordVisible: isPasswordVisible,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _OptionsRow(
            rememberMe: rememberMe,
            onRememberMeToggle: onRememberMeToggle,
          ),
          const SizedBox(height: 32),
          _OptimizedLoginButton(
            isLoading: isLoading,
            onLogin: onLogin,
          ),
        ],
      ),
    );
  }
}

class _PhoneTextField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCountryCode;
  final String selectedCountryFlag;
  final VoidCallback onCountryPickerTap;

  const _PhoneTextField({
    required this.controller,
    required this.selectedCountryCode,
    required this.selectedCountryFlag,
    required this.onCountryPickerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _LoginScreenState._textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country Code Selector
            GestureDetector(
              onTap: onCountryPickerTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _LoginScreenState._borderGrey,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _LoginScreenState._textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: _LoginScreenState._textGrey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Phone Input
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  _NoLeadingZeroFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter phone number';
                  }
                  if (value.length < 9) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '24 XXX XXXX',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: _LoginScreenState._primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: _LoginScreenState._inputBorderRadius,
                    borderSide: const BorderSide(
                      color: _LoginScreenState._borderGrey,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: _LoginScreenState._inputBorderRadius,
                    borderSide: const BorderSide(
                      color: _LoginScreenState._borderGrey,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _LoginScreenState._inputBorderRadius,
                    borderSide: const BorderSide(
                      color: _LoginScreenState._primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: _LoginScreenState._inputBorderRadius,
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: _LoginScreenState._inputBorderRadius,
                    borderSide: const BorderSide(
                      color: Colors.red,
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
                style: const TextStyle(
                  fontSize: 15,
                  color: _LoginScreenState._textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptimizedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool isPassword;
  final bool? isPasswordVisible;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final VoidCallback? onToggleVisibility;

  const _OptimizedTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.isPassword = false,
    this.isPasswordVisible,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onToggleVisibility,
  });

  @override
  State<_OptimizedTextField> createState() => _OptimizedTextFieldState();
}

class _OptimizedTextFieldState extends State<_OptimizedTextField> {
  late final FocusNode _focusNode;
  late final InputDecoration _normalDecoration;
  late final InputDecoration _normalPasswordDecoration;
  late final InputDecoration _visiblePasswordDecoration;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _normalDecoration = _buildDecoration(
      hint: widget.hint,
      icon: widget.icon,
      suffixIcon: null,
    );

    if (widget.isPassword) {
      _normalPasswordDecoration = _buildDecoration(
        hint: widget.hint,
        icon: widget.icon,
        suffixIcon: Icons.visibility_off_outlined,
      );

      _visiblePasswordDecoration = _buildDecoration(
        hint: widget.hint,
        icon: widget.icon,
        suffixIcon: Icons.visibility_outlined,
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  InputDecoration _buildDecoration({
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: _LoginScreenState._primaryColor,
      ),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(
                suffixIcon,
                color: const Color(0xFF9E9E9E),
                size: 20,
              ),
              onPressed: widget.onToggleVisibility,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: _LoginScreenState._inputBorderRadius,
        borderSide: const BorderSide(
          color: _LoginScreenState._borderGrey,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _LoginScreenState._inputBorderRadius,
        borderSide: const BorderSide(
          color: _LoginScreenState._borderGrey,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _LoginScreenState._inputBorderRadius,
        borderSide: const BorderSide(
          color: _LoginScreenState._primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _LoginScreenState._inputBorderRadius,
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _LoginScreenState._inputBorderRadius,
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  InputDecoration get _currentDecoration {
    if (!widget.isPassword) return _normalDecoration;
    return widget.isPasswordVisible!
        ? _visiblePasswordDecoration
        : _normalPasswordDecoration;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _LoginScreenState._textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              validator: widget.validator,
              keyboardAppearance: Brightness.light,
              textCapitalization: TextCapitalization.none,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              showCursor: true,
              cursorWidth: 1.5,
              cursorHeight: 20.0,
              cursorRadius: const Radius.circular(1),
              cursorColor: _LoginScreenState._primaryColor,
              cursorOpacityAnimates: false,
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
              enableInteractiveSelection: true,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              maxLines: 1,
              expands: false,
              toolbarOptions: const ToolbarOptions(
                copy: true,
                cut: true,
                paste: true,
                selectAll: true,
              ),
              decoration: _currentDecoration,
              style: const TextStyle(
                fontSize: 15,
                color: _LoginScreenState._textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _OptionsRow extends StatelessWidget {
  final bool rememberMe;
  final VoidCallback onRememberMeToggle;

  const _OptionsRow({
    required this.rememberMe,
    required this.onRememberMeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onRememberMeToggle,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: rememberMe
                      ? _LoginScreenState._primaryColor
                      : Colors.white,
                  border: Border.all(
                    color: rememberMe
                        ? _LoginScreenState._primaryColor
                        : _LoginScreenState._borderGrey,
                    width: rememberMe ? 1 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: rememberMe
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember me',
                style: TextStyle(
                  fontSize: 13,
                  color: _LoginScreenState._textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ForgotPasswordScreen(),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _LoginScreenState._primaryColor,
              decoration: TextDecoration.underline,
              decorationColor: _LoginScreenState._primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptimizedLoginButton extends StatelessWidget {
  final bool isLoading;
  final Future<void> Function() onLogin;

  const _OptimizedLoginButton({
    required this.isLoading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _LoginScreenState._primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: _LoginScreenState._primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: _LoginScreenState._buttonBorderRadius,
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Sign In',
                    style: TextStyle(
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

class _SignUpLink extends StatelessWidget {
  const _SignUpLink();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(
            fontSize: 14,
            color: _LoginScreenState._textGrey,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const GetStartedScreen(),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: const Text(
            'Get Started',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _LoginScreenState._primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryPicker extends StatelessWidget {
  final List<Map<String, String>> countries;
  final Function(String code, String flag) onCountrySelected;

  const _CountryPicker({
    required this.countries,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 20),
          const Text(
            'Select Country',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...countries.map((country) => ListTile(
            leading: Text(
              country['flag']!,
              style: const TextStyle(fontSize: 28),
            ),
            title: Text(
              country['name']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              country['code']!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              onCountrySelected(country['code']!, country['flag']!);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
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
