import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/profile_service.dart';
import '../../utils/api_config.dart'; 

class PersonalInformationScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ Changed from nurseData to userData
  
  const PersonalInformationScreen({
    Key? key,
    required this.userData, // ✅ Changed from nurseData to userData
  }) : super(key: key);

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  
  bool _isEditing = false;
  bool _isSaving = false;
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ghanaCardController;
  late TextEditingController _licenseController;
  late TextEditingController _yearsExpController;
  
  String _selectedGender = 'male';
  String? _selectedSpecialization;
  DateTime _selectedDate = DateTime.now();

  // Specialization options
  final List<Map<String, String>> _specializationOptions = [
    {'value': 'pediatric_care', 'label': 'Pediatric Care'},
    {'value': 'general_care', 'label': 'General Care'},
    {'value': 'emergency_care', 'label': 'Emergency Care'},
    {'value': 'oncology', 'label': 'Oncology'},
    {'value': 'cardiology', 'label': 'Cardiology'},
    {'value': 'psychiatric_care', 'label': 'Psychiatric Care'},
    {'value': 'geriatric_care', 'label': 'Geriatric Care'},
    {'value': 'surgical_care', 'label': 'Surgical Care'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _checkToken() async {
    try {
      final result = await _profileService.getProfile();
      print('🔑 Token check - Success: ${result['success']}');
      if (!result['success']) {
        print('❌ Token issue: ${result['message']}');
      }
    } catch (e) {
      print('❌ Token check error: $e');
    }
  }

  void _initializeControllers() {
    print('🔍 Initializing with userData: ${widget.userData}'); // ✅ Changed
    
    _firstNameController = TextEditingController(
      text: widget.userData['firstName'] ?? widget.userData['first_name'] ?? '' // ✅ Changed
    );
    _lastNameController = TextEditingController(
      text: widget.userData['lastName'] ?? widget.userData['last_name'] ?? '' // ✅ Changed
    );
    _emailController = TextEditingController(
      text: widget.userData['email'] ?? '' // ✅ Changed
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '' // ✅ Changed
    );
    
    final ghanaCard = widget.userData['ghanaCard'] ??  // ✅ Changed
                      widget.userData['ghana_card_number'] ?? 
                      widget.userData['ghanaCardNumber'] ?? '';
    _ghanaCardController = TextEditingController(text: ghanaCard);
    
    final license = widget.userData['license'] ??  // ✅ Changed
                    widget.userData['license_number'] ?? 
                    widget.userData['licenseNumber'] ?? '';
    _licenseController = TextEditingController(text: license);
    
    // Initialize specialization from userData
    final specialization = widget.userData['specialization'] ?? ''; // ✅ Changed
    _selectedSpecialization = specialization.isNotEmpty ? specialization : null;
    
    // Check all possible key variations for years of experience
    var yearsExpValue = widget.userData['years_of_experience'] ??  // ✅ Changed
                        widget.userData['yearsOfExperience'] ?? 
                        widget.userData['years_experience'] ??
                        widget.userData['years_exp'];
    
    print('🔍 Initial years_of_experience value: $yearsExpValue (type: ${yearsExpValue.runtimeType})');
    
    int yearsExp = 0;
    if (yearsExpValue != null) {
      if (yearsExpValue is int) {
        yearsExp = yearsExpValue;
      } else if (yearsExpValue is String) {
        yearsExp = int.tryParse(yearsExpValue) ?? 0;
      } else if (yearsExpValue is double) {
        yearsExp = yearsExpValue.toInt();
      }
    }
    
    _yearsExpController = TextEditingController(text: yearsExp.toString());
    print('✅ Initial years of experience set to: $yearsExp');
    
    _selectedGender = widget.userData['gender'] ?? 'male'; // ✅ Changed
    
    String? dobString = widget.userData['dateOfBirth'] ??  // ✅ Changed
                        widget.userData['date_of_birth'] ?? 
                        widget.userData['dob'];
    _selectedDate = dobString != null ? DateTime.tryParse(dobString) ?? DateTime(1990, 1, 1) : DateTime(1990, 1, 1);
  }

  void _updateControllersWithData(Map<String, dynamic> data) {
    print('🔄 Updating controllers with fresh data: $data');
    
    _firstNameController.text = data['firstName'] ?? data['first_name'] ?? '';
    _lastNameController.text = data['lastName'] ?? data['last_name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    
    final ghanaCard = data['ghanaCard'] ?? 
                      data['ghana_card_number'] ?? 
                      data['ghanaCardNumber'] ?? '';
    _ghanaCardController.text = ghanaCard;
    
    final license = data['license'] ?? 
                    data['license_number'] ?? 
                    data['licenseNumber'] ?? '';
    _licenseController.text = license;
    
    // Update specialization
    final specialization = data['specialization'] ?? '';
    _selectedSpecialization = specialization.isNotEmpty ? specialization : null;
    print('📋 Specialization updated to: $_selectedSpecialization');
    
    // Update years of experience - check all possible key variations
    var yearsExpValue = data['years_of_experience'] ?? 
                        data['yearsOfExperience'] ?? 
                        data['years_experience'] ??
                        data['years_exp'];
    
    print('🔍 Raw years_of_experience value: $yearsExpValue (type: ${yearsExpValue.runtimeType})');
    
    int yearsExp = 0;
    if (yearsExpValue != null) {
      if (yearsExpValue is int) {
        yearsExp = yearsExpValue;
      } else if (yearsExpValue is String) {
        yearsExp = int.tryParse(yearsExpValue) ?? 0;
      } else if (yearsExpValue is double) {
        yearsExp = yearsExpValue.toInt();
      }
    }
    
    _yearsExpController.text = yearsExp.toString();
    print('✅ Years of experience updated to: $yearsExp (controller text: ${_yearsExpController.text})');
    
    _selectedGender = data['gender'] ?? 'male';
    
    String? dobString = data['dateOfBirth'] ?? 
                        data['date_of_birth'] ?? 
                        data['dob'];
    _selectedDate = dobString != null ? DateTime.tryParse(dobString) ?? DateTime(1990, 1, 1) : DateTime(1990, 1, 1);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ghanaCardController.dispose();
    _licenseController.dispose();
    _yearsExpController.dispose();
    super.dispose();
  }

  String _getInitials() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    
    if (firstName.isEmpty && lastName.isEmpty) return 'NU';
    if (firstName.isEmpty) return lastName[0].toUpperCase();
    if (lastName.isEmpty) return firstName[0].toUpperCase();
    
    return '${firstName[0]}${lastName[0]}'.toUpperCase();
  }

  Widget _buildInitialsAvatar() {
    final initials = _getInitials();
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

  String _getSpecializationLabel(String? value) {
    if (value == null) return 'Not specified';
    final option = _specializationOptions.firstWhere(
      (opt) => opt['value'] == value,
      orElse: () => {'label': value},
    );
    return option['label'] ?? value;
  }

  // ✅ Helper method to check if user is a nurse
  bool _isNurse() {
    // Check if user has nurse-specific fields or a role/user_type field
    final userType = widget.userData['user_type'] ?? 
                     widget.userData['role'] ?? 
                     widget.userData['userType'] ?? '';
    
    // Check by user type
    if (userType.toString().toLowerCase() == 'nurse') return true;
    
    // Or check if professional fields exist (license, specialization)
    final hasLicense = widget.userData['license'] != null || 
                       widget.userData['license_number'] != null ||
                       widget.userData['licenseNumber'] != null;
    
    return hasLicense;
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
          'Personal Information',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSection(),
              const SizedBox(height: 24),
              _buildBasicInfoSection(),
              // ✅ Only show professional section for nurses
              if (_isNurse()) ...[
                const SizedBox(height: 20),
                _buildProfessionalSection(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: _isEditing ? _buildBottomActions() : null,
    );
  }

  Widget _buildProfileSection() {
    final avatarPath = widget.userData['avatar']; // ✅ Changed
    final fullAvatarUrl = ApiConfig.getAvatarUrl(avatarPath);
    
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fallbackUrl = fullAvatarUrl.isEmpty
        ? 'https://ui-avatars.com/api/?name=$firstName+$lastName&background=199A8E&color=fff&size=200'
        : fullAvatarUrl;

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width - 40,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.network(
                  fallbackUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildInitialsAvatar();
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_firstNameController.text} ${_lastNameController.text}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // ✅ Only show license badge for nurses
            if (_isNurse() && _licenseController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _licenseController.text,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.person_outline,
      iconColor: const Color(0xFF6C63FF),
      iconBg: const Color(0xFFEDE9FF),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person_outline,
                enabled: _isEditing,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
                enabled: _isEditing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: _isEditing,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          enabled: _isEditing,
        ),
        const SizedBox(height: 16),
        _buildGenderSelector(),
        const SizedBox(height: 16),
        _buildDatePicker(),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _ghanaCardController,
          label: 'Ghana Card Number',
          icon: Icons.badge_outlined,
          enabled: _isEditing,
        ),
      ],
    );
  }

  Widget _buildProfessionalSection() {
    return _buildSection(
      title: 'Professional Information',
      icon: Icons.work_outline,
      iconColor: AppColors.primaryGreen,
      iconBg: const Color(0xFFE8F5F5),
      children: [
        _buildTextField(
          controller: _licenseController,
          label: 'License Number',
          icon: Icons.badge_outlined,
          enabled: _isEditing,
        ),
        const SizedBox(height: 16),
        _buildSpecializationDropdown(),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _yearsExpController,
          label: 'Years of Experience',
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
          enabled: _isEditing,
        ),
      ],
    );
  }

  Widget _buildSpecializationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Specialization',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _isEditing ? Colors.grey.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _isEditing
              ? DropdownButtonFormField<String>(
                  value: _selectedSpecialization,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  hint: Text(
                    'Select specialization',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  items: _specializationOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option['value'],
                      child: Text(
                        option['label']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
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
                    if (value == null || value.isEmpty) {
                      return 'Please select a specialization';
                    }
                    return null;
                  },
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getSpecializationLabel(_selectedSpecialization),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required List<Widget> children,
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
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15,
        color: enabled ? const Color(0xFF1A1A1A) : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
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
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Gender',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('Male', 'male', Icons.male),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Female', 'female', Icons.female),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Other', 'other', Icons.people),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String label, String value, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: _isEditing ? () => setState(() => _selectedGender = value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _isEditing ? () => _selectDate(context) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isEditing ? Colors.grey.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _isEditing ? const Color(0xFF1A1A1A) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing)
              Icon(
                Icons.arrow_drop_down,
                color: Colors.grey.shade600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () {
                  setState(() {
                    _isEditing = false;
                    // Reset to original data when canceling
                    _updateControllersWithData(widget.userData); // ✅ Changed
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveChanges() async {
    print('🔵 Save button clicked');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    print('✅ Form validation passed');
    setState(() => _isSaving = true);
    
    try {
      // Prepare basic data (common to both nurses and patients)
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final gender = _selectedGender;
      final dateOfBirth = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final ghanaCard = _ghanaCardController.text.trim();
      
      print('📦 Prepared data for update');
      print('   Name: $firstName $lastName');
      print('   Email: $email');
      print('   Phone: $phone');
      print('   User Type: ${_isNurse() ? "Nurse" : "Patient"}');
      
      // ✅ Prepare professional data only for nurses
      String licenseNumber = '';
      String specialization = '';
      int yearsExp = 0;
      
      if (_isNurse()) {
        licenseNumber = _licenseController.text.trim();
        specialization = _selectedSpecialization ?? '';
        yearsExp = int.tryParse(_yearsExpController.text.trim()) ?? 0;
        
        print('   Professional Info (Nurse):');
        print('   License: $licenseNumber');
        print('   Specialization: $specialization');
        print('   Years of Experience: $yearsExp');
      }
      
      // Call API
      print('🔄 Calling profile update API...');
      final result = await _profileService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        ghanaCard: ghanaCard,
        // ✅ Pass empty/default values for patients, actual values for nurses
        licenseNumber: licenseNumber,
        specialization: specialization,
        yearsOfExperience: yearsExp,
      );

      print('📡 API Response - Success: ${result['success']}');
      print('📡 Message: ${result['message']}');
      if (result['data'] != null) {
        print('📡 Returned data keys: ${result['data'].keys}');
        if (_isNurse()) {
          print('📡 Years of experience in response: ${result['data']['years_of_experience'] ?? result['data']['yearsOfExperience'] ?? result['data']['yearsExp']}');
        }
      }

      setState(() => _isSaving = false);

      if (result['success']) {
        print('✅ Profile updated successfully!');
        
        // Update controllers with fresh data from API response
        if (result['data'] != null) {
          print('📥 Received updated data from API');
          if (_isNurse()) {
            print('   Years of experience in response: ${result['data']['years_of_experience']}');
          }
          
          setState(() {
            _updateControllersWithData(result['data']);
            _isEditing = false;
          });
        } else {
          // Exit edit mode even if no data returned
          setState(() => _isEditing = false);
        }
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Profile updated successfully!'),
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
          
          // Return updated data to parent screen
          print('🔙 Returning updated data to parent screen');
          Navigator.pop(context, result['data']);
        }
      } else {
        print('❌ Profile update failed: ${result['message']}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception occurred: $e');
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }
}