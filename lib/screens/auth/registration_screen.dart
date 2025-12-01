import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/auth/auth_models.dart';
import '../../services/auth/auth_service.dart';
import '../auth/pending_approval_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const Color _primaryColor = Color(0xFF199A8E);
  static const Color _nurseColor = Color(0xFF6C63FF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nursePinController = TextEditingController();
  final _ghanaCardNumberController = TextEditingController();
  
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  String _selectedUserType = 'patient';
  String _selectedCountryCode = '+233';
  String _selectedCountryFlag = '🇬🇭';
  bool _isLoading = false;
  bool _acceptTerms = false;

  // Image files for nurse documents
  File? _ghanaCardFront;
  File? _ghanaCardBack;
  File? _nursePinFront;
  File? _nursePinBack;

  final List<Map<String, String>> _countries = [
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nursePinController.dispose();
    _ghanaCardNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          switch (imageType) {
            case 'ghana_front':
              _ghanaCardFront = File(image.path);
              break;
            case 'ghana_back':
              _ghanaCardBack = File(image.path);
              break;
            case 'pin_front':
              _nursePinFront = File(image.path);
              break;
            case 'pin_back':
              _nursePinBack = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showSnackbar('Failed to pick image. Please try again.', isError: true);
    }
  }

  Future<void> _showImageSourceDialog(String imageType) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(imageType, ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(imageType, ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _nurseColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _nurseColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _pickImageFromSource(String imageType, ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          switch (imageType) {
            case 'ghana_front':
              _ghanaCardFront = File(image.path);
              break;
            case 'ghana_back':
              _ghanaCardBack = File(image.path);
              break;
            case 'pin_front':
              _nursePinFront = File(image.path);
              break;
            case 'pin_back':
              _nursePinBack = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showSnackbar('Failed to pick image. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildUserTypeSelector(),
                      const SizedBox(height: 24),
                      _buildPersonalInfoSection(),
                      if (_selectedUserType == 'nurse') ...[
                        const SizedBox(height: 24),
                        _buildDocumentsSection(),
                      ],
                      const SizedBox(height: 24),
                      _buildTermsCheckbox(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Request a Callback',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: _primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re Excited to Help!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Fill in your details and our team will call you back shortly.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('I am a...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildUserTypeCard('patient', 'Patient', Icons.person_outline_rounded, _primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildUserTypeCard('nurse', 'Healthcare Professional', Icons.medical_services_outlined, _nurseColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTypeCard(String value, String title, IconData icon, Color color) {
    final isSelected = _selectedUserType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedUserType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 6),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.white : Colors.grey.shade400, width: 2),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: isSelected ? Icon(Icons.check, size: 12, color: color) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.badge_outlined,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'your.email@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPhoneField(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w400),
            prefixIcon: Icon(icon, size: 20, color: _primaryColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryColor, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Text(_selectedCountryFlag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(_selectedCountryCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _NoLeadingZeroFormatter()],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.length < 9) return 'Too short';
                  return null;
                },
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryColor, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  Widget _buildDocumentsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, color: _nurseColor, size: 20),
              const SizedBox(width: 8),
              const Text('Required Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Upload clear images of your documents', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          
          // Ghana Card Number
          _buildTextField(
            controller: _ghanaCardNumberController,
            label: 'Ghana Card Number',
            hint: 'GHA-XXXXXXXXX-X',
            icon: Icons.credit_card_rounded,
            textCapitalization: TextCapitalization.characters,
            validator: (v) => _selectedUserType == 'nurse' && (v == null || v.trim().isEmpty) ? 'Ghana Card number is required' : null,
          ),
          const SizedBox(height: 16),
          
          // Ghana Card
          _buildDocumentUploader(
            title: 'Ghana Card',
            icon: Icons.credit_card_rounded,
            frontImage: _ghanaCardFront,
            backImage: _ghanaCardBack,
            onFrontTap: () => _showImageSourceDialog('ghana_front'),
            onBackTap: () => _showImageSourceDialog('ghana_back'),
          ),
          const SizedBox(height: 20),
          
          // Nurse PIN Input
          _buildTextField(
            controller: _nursePinController,
            label: 'Nurse PIN Number',
            hint: 'Enter your Nurse PIN',
            icon: Icons.pin_outlined,
            validator: (v) => _selectedUserType == 'nurse' && (v == null || v.trim().isEmpty) ? 'Required for nurses' : null,
          ),
          const SizedBox(height: 16),
          
          // Nurse PIN Card
          _buildDocumentUploader(
            title: 'Nurse PIN Card',
            icon: Icons.badge_outlined,
            frontImage: _nursePinFront,
            backImage: _nursePinBack,
            onFrontTap: () => _showImageSourceDialog('pin_front'),
            onBackTap: () => _showImageSourceDialog('pin_back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploader({
    required String title,
    required IconData icon,
    required File? frontImage,
    required File? backImage,
    required VoidCallback onFrontTap,
    required VoidCallback onBackTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _nurseColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildImageUploadBox('Front', frontImage, onFrontTap)),
            const SizedBox(width: 12),
            Expanded(child: _buildImageUploadBox('Back', backImage, onBackTap)),
          ],
        ),
      ],
    );
  }

  Widget _buildImageUploadBox(String label, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: image != null ? Colors.transparent : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: image != null ? _primaryColor : Colors.grey.shade300, width: image != null ? 2 : 1),
        ),
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(image, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                      ),
                      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 24),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
          color: _acceptTerms ? _primaryColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _acceptTerms ? _primaryColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _acceptTerms ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _acceptTerms ? _primaryColor : Colors.grey.shade300, width: 2),
              ),
              child: _acceptTerms ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  children: const [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(text: 'Terms of Service', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600)),
                    TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final Color buttonColor = _selectedUserType == 'nurse' ? _nurseColor : _primaryColor;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: buttonColor.withOpacity(0.6),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _selectedUserType == 'nurse' ? 'Submit Application' : 'Request Callback',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _CountryPickerSheet(
        countries: _countries,
        onSelected: (code, flag) => setState(() { _selectedCountryCode = code; _selectedCountryFlag = flag; }),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_acceptTerms) {
      _showSnackbar('Please accept the Terms of Service', isError: true);
      return;
    }
    
    if (_selectedUserType == 'nurse') {
      if (_ghanaCardFront == null || _ghanaCardBack == null) {
        _showSnackbar('Please upload both sides of your Ghana Card', isError: true);
        return;
      }
      if (_nursePinFront == null || _nursePinBack == null) {
        _showSnackbar('Please upload both sides of your Nurse PIN Card', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Create callback request
      final request = CallbackRequest(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        countryCode: _selectedCountryCode,
        role: _selectedUserType,
        nursePin: _selectedUserType == 'nurse' ? _nursePinController.text.trim() : null,
        ghanaCardNumber: _selectedUserType == 'nurse' ? _ghanaCardNumberController.text.trim() : null,
        ghanaCardFront: _ghanaCardFront,
        ghanaCardBack: _ghanaCardBack,
        nursePinFront: _nursePinFront,
        nursePinBack: _nursePinBack,
      );

      // Call API
      final response = await _authService.requestCallback(request);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.success) {
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
        if (response.errors != null && response.errors!.isNotEmpty) {
          final errorMessages = <String>[];
          response.errors!.forEach((key, value) {
            if (value is List) {
              errorMessages.addAll(value.cast<String>());
            } else {
              errorMessages.add(value.toString());
            }
          });
          _showSnackbar(errorMessages.join('\n'), isError: true);
        } else {
          _showSnackbar(response.message, isError: true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showSnackbar('An error occurred. Please try again.', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.startsWith('0')) return oldValue;
    return newValue;
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final List<Map<String, String>> countries;
  final Function(String, String) onSelected;

  const _CountryPickerSheet({required this.countries, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Select Country', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...countries.map((c) => ListTile(
          leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
          title: Text(c['name']!),
          trailing: Text(c['code']!, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          onTap: () {
            onSelected(c['code']!, c['flag']!);
            Navigator.pop(context);
          },
        )),
        const SizedBox(height: 20),
      ],
    );
  }
}