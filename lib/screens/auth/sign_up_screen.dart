import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../services/auth/auth_service.dart';
import '../../models/auth/auth_models.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';

/// Ultra-Optimized SignUp Screen - No animations, debounced typing
/// Perfect for low-end devices with minimal CPU usage
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Healthcare professional fields
  final _licenseNumberController = TextEditingController();
  String? _selectedSpecialization;

  // Auth service
  final _authService = AuthService();

  String _selectedUserType = 'patient';
  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  int _currentStep = 1;
  final int _totalSteps = 3;
  
  // Country selection
  String _selectedCountryCode = '+233';
  String _selectedCountryFlag = '🇬🇭';

  final List<Map<String, String>> _countries = [
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];
  
  // OPTIMIZED: Password strength tracking
  int _passwordStrength = 0;
  String _passwordStrengthText = 'Enter password';
  Color _passwordStrengthColor = Colors.grey;
  Timer? _passwordDebounce;

  @override
  void initState() {
    super.initState();
    // OPTIMIZED: Only listen to password changes, debounced
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordDebounce?.cancel();
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  // OPTIMIZED: Debounced password strength calculation
  void _onPasswordChanged() {
    // Cancel previous timer
    _passwordDebounce?.cancel();
    
    // Set new timer - only calculate after user stops typing for 300ms
    _passwordDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _calculatePasswordStrength();
      }
    });
  }

  // OPTIMIZED: Calculate strength only when needed, not on every keystroke
  void _calculatePasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    String strengthText = 'Enter password';
    Color strengthColor = Colors.grey;
    
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
          strengthColor = const Color(0xFF199A8E);
          break;
      }
    }
    
    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = strengthText;
      _passwordStrengthColor = strengthColor;
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Simple header
            _buildHeader(),
            
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildFormContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF1A1A1A),
                size: 20,
              ),
            ),
          ),
          
          // Step indicator
          _buildStepIndicator(),
          
          // Help button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF199A8E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF199A8E).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF199A8E),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index < _currentStep;
          final isCurrent = index == _currentStep - 1;
          
          return Container(
            margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
            width: isCurrent ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF199A8E)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Simple card
        _buildSimpleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 30),
              
              if (_currentStep == 1) _buildStep1(),
              if (_currentStep == 2) _buildStep2(),
              if (_currentStep == 3) _buildStep3(),
              
              const SizedBox(height: 30),
              _buildActionButtons(),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        _buildBottomLink(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSimpleCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildWelcomeSection() {
    String title = '';
    String subtitle = '';
    
    switch (_currentStep) {
      case 1:
        title = 'Create Account';
        subtitle = 'Start your healthcare journey with us';
        break;
      case 2:
        title = 'Secure Your Account';
        subtitle = 'Set up a strong password for protection';
        break;
      case 3:
        title = 'Choose Your Role';
        subtitle = 'How will you be using our services?';
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            letterSpacing: -1,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            letterSpacing: -0.2,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _currentStep == 1 ? _formKey : null,
      child: Column(
        children: [
          _buildSimpleTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildSimpleTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'your.email@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildPhoneField(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
            children: [
              TextSpan(text: 'Phone Number '),
              TextSpan(
                text: '(Enter without leading 0)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country code selector
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedCountryFlag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountryCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
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
            // Phone number input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _NoLeadingZeroFormatter(),
                ],
                onChanged: (value) {
                  // Remove leading zero if user somehow manages to enter it
                  if (value.startsWith('0') && value.length > 0) {
                    _phoneController.text = value.substring(1);
                    _phoneController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _phoneController.text.length),
                    );
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.startsWith('0')) {
                    return 'Phone number should not start with 0';
                  }
                  if (value.length < 9) {
                    return 'Phone number is too short';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF199A8E),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _currentStep == 2 ? _formKey : null,
      child: Column(
        children: [
          _buildSimpleTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a strong password',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isPasswordVisible,
            isPassword: true,
            onTogglePassword: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildSimpleTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isConfirmPasswordVisible,
            isPassword: true,
            onTogglePassword: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildPasswordStrengthIndicator(),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        _buildUserTypeSelection(),
        const SizedBox(height: 25),
        
        // Show healthcare professional fields if nurse is selected
        if (_selectedUserType == 'nurse') ...[
          _buildSimpleTextField(
            controller: _licenseNumberController,
            label: 'License Number',
            hint: 'Enter your professional license number',
            icon: Icons.badge_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'License number is required for healthcare professionals';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildSpecializationDropdown(),
          const SizedBox(height: 25),
        ],
        
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildSimpleTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: const Color(0xFF199A8E),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF199A8E),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _passwordStrengthColor,
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
                  color: index < _passwordStrength 
                      ? _passwordStrengthColor 
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSpecializationDropdown() {
    final specializations = [
      {'value': 'pediatric_care', 'label': 'Pediatric Care'},
      {'value': 'general_care', 'label': 'General Care'},
      {'value': 'emergency_care', 'label': 'Emergency Care'},
      {'value': 'oncology', 'label': 'Oncology'},
      {'value': 'cardiology', 'label': 'Cardiology'},
      {'value': 'psychiatric_care', 'label': 'Psychiatric Care'},
      {'value': 'geriatric_care', 'label': 'Geriatric Care'},
      {'value': 'surgical_care', 'label': 'Surgical Care'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specialization',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedSpecialization,
            decoration: InputDecoration(
              hintText: 'Select your specialization',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.medical_services_outlined,
                size: 20,
                color: Color(0xFF199A8E),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF199A8E),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: specializations.map((spec) {
              return DropdownMenuItem<String>(
                value: spec['value'],
                child: Text(
                  spec['label']!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSpecialization = value;
              });
            },
            validator: (value) {
              if (_selectedUserType == 'nurse' && 
                  (value == null || value.isEmpty)) {
                return 'Please select your specialization';
              }
              return null;
            },
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade600,
            ),
            dropdownColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeSelection() {
    return Column(
      children: [
        _buildUserTypeCard(
          value: 'patient',
          title: 'Patient',
          description: 'Receive healthcare services',
          icon: Icons.person_outline_rounded,
          color: const Color(0xFF199A8E),
        ),
        const SizedBox(height: 15),
        _buildUserTypeCard(
          value: 'nurse',
          title: 'Healthcare Professional',
          description: 'Provide medical services',
          icon: Icons.medical_services_outlined,
          color: const Color(0xFF6C63FF),
        ),
      ],
    );
  }

  Widget _buildUserTypeCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedUserType == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedUserType = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: color,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _acceptTerms
              ? const Color(0xFF199A8E).withOpacity(0.05)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _acceptTerms
                ? const Color(0xFF199A8E)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _acceptTerms ? const Color(0xFF199A8E) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _acceptTerms
                      ? const Color(0xFF199A8E)
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: _acceptTerms
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    const TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: Color(0xFF199A8E),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    const TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Color(0xFF199A8E),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF199A8E),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF199A8E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF199A8E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                disabledBackgroundColor: const Color(0xFF199A8E).withOpacity(0.6),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _currentStep == _totalSteps
                      ? const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF199A8E),
            ),
          ),
        ),
      ],
    );
  }

  void _handleNext() async {
    if (_currentStep < _totalSteps) {
      // Validate current step
      if (_formKey.currentState?.validate() ?? false) {
        setState(() {
          _currentStep++;
        });
      }
    } else {
      // Final submission - validate step 3
      if (!_acceptTerms) {
        _showErrorSnackbar('Please accept the Terms of Service and Privacy Policy');
        return;
      }

      // Validate healthcare professional fields
      if (_selectedUserType == 'nurse') {
        if (_licenseNumberController.text.trim().isEmpty) {
          _showErrorSnackbar('License number is required for healthcare professionals');
          return;
        }
        
        if (_selectedSpecialization == null || _selectedSpecialization!.isEmpty) {
          _showErrorSnackbar('Please select your specialization');
          return;
        }
      }
      
      // Start loading
      setState(() => _isLoading = true);
      
      try {
        // Create registration request
        final registerRequest = RegisterRequest(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          countryCode: _selectedCountryCode,
          password: _passwordController.text,
          passwordConfirmation: _confirmPasswordController.text,
          role: _selectedUserType,
          licenseNumber: _selectedUserType == 'nurse' 
              ? _licenseNumberController.text.trim() 
              : null,
          specialization: _selectedUserType == 'nurse' 
              ? _selectedSpecialization 
              : null,
        );

        // Call API
        final response = await _authService.register(registerRequest);

        // Stop loading
        setState(() => _isLoading = false);

        if (!mounted) return;

        if (response.success) {
          // Registration successful - navigate to pending approval screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PendingApprovalScreen(
                userName: _nameController.text.trim(),
                userEmail: _emailController.text.trim(),
                userRole: _selectedUserType,
              ),
            ),
          );
        } else {
          // Show error message
          if (response.errors != null && response.errors!.isNotEmpty) {
            // Show validation errors
            final errorMessages = <String>[];
            response.errors!.forEach((key, value) {
              if (value is List) {
                errorMessages.addAll(value.cast<String>());
              } else {
                errorMessages.add(value.toString());
              }
            });
            _showErrorSnackbar(errorMessages.join('\n'));
          } else {
            _showErrorSnackbar(response.message);
          }
        }
      } catch (e) {
        // Stop loading
        setState(() => _isLoading = false);
        
        if (mounted) {
          _showErrorSnackbar('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Custom formatter to prevent leading zero in phone numbers
class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith('0')) {
      return oldValue;
    }
    return newValue;
  }
}

// Country Picker Widget
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
                    color: Colors.grey,
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