import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/contact_person/contact_person_models.dart';
import '../../services/contact_person/contact_person_auth_service.dart';
import 'patient_selector_screen.dart';

class ContactPersonLoginScreen extends StatefulWidget {
  const ContactPersonLoginScreen({super.key});

  @override
  State<ContactPersonLoginScreen> createState() => _ContactPersonLoginScreenState();
}

class _ContactPersonLoginScreenState extends State<ContactPersonLoginScreen> {
  static const Color _primaryColor = Color(0xFF199A8E);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF666666);
  static const Color _borderGrey = Color(0xFFE5E5E5);
  static const Color _backgroundGrey = Color(0xFFF8FAFB);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = ContactPersonAuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      FocusScope.of(context).unfocus();

      try {
        final phone = _phoneController.text.trim();
        debugPrint('[ContactPersonLogin] Attempting login for: $phone');

        final response = await _authService.login(phone);

        debugPrint('[ContactPersonLogin] Response received - success: ${response.success}, hasUser: ${response.user != null}');

        if (!mounted) {
          debugPrint('[ContactPersonLogin] Widget not mounted, aborting');
          return;
        }

        if (response.success) {
          debugPrint('[ContactPersonLogin] Login successful, attempting navigation');

          if (response.user != null) {
            debugPrint('[ContactPersonLogin] Navigating with response.user');
            _navigateToPatientSelector(response.user!);
          } else {
            // Login successful but no user data - try to get stored data
            debugPrint('[ContactPersonLogin] No user in response, trying stored data');
            final storedUser = await _authService.getStoredContactPerson();
            debugPrint('[ContactPersonLogin] Stored user: ${storedUser != null}');

            if (storedUser != null && mounted) {
              debugPrint('[ContactPersonLogin] Navigating with stored user');
              _navigateToPatientSelector(storedUser);
            } else if (mounted) {
              debugPrint('[ContactPersonLogin] No stored user, showing error');
              _showErrorMessage('Login successful but failed to load user data');
            }
          }
        } else {
          debugPrint('[ContactPersonLogin] Login failed: ${response.message}');
          _showErrorMessage(response.message.isNotEmpty
              ? response.message
              : 'Login failed. Please try again.');
        }
      } catch (e, stackTrace) {
        debugPrint('[ContactPersonLogin] Error: $e');
        debugPrint('[ContactPersonLogin] Stack trace: $stackTrace');
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

  void _navigateToPatientSelector(ContactPersonUser contactPerson) {
    debugPrint('[ContactPersonLogin] _navigateToPatientSelector called');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => PatientSelectorScreen(
          contactPerson: contactPerson,
        ),
      ),
      (route) => false,
    );
    debugPrint('[ContactPersonLogin] Navigation completed');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundGrey,
      appBar: AppBar(
        backgroundColor: _backgroundGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 4,
                backgroundColor: _primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'Contact Person Login',
                style: TextStyle(
                  fontSize: 12,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Header
                const Text(
                  'Login with\nPhone Number',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                    letterSpacing: -1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your registered phone number to access patient information',
                  style: TextStyle(
                    fontSize: 15,
                    color: _textGrey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Phone field
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '0244000000',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _borderGrey,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _borderGrey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _primaryColor.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'As a contact person, you can view and manage the patient\'s healthcare information.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textGrey,
                            height: 1.4,
                          ),
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
}
