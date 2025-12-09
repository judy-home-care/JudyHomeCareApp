import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/care_plans/care_plan_service.dart';
import '../../models/care_plans/care_plan_models.dart';
import '../../widgets/searchable_dropdown.dart';

class CreateCarePlanModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const CreateCarePlanModal({
    Key? key,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<CreateCarePlanModal> createState() => _CreateCarePlanModalState();
}

class _CreateCarePlanModalState extends State<CreateCarePlanModal> {
  final _formKey = GlobalKey<FormState>();
  final _carePlanService = CarePlanService();
  bool _isSaving = false;

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customFrequencyController = TextEditingController();

  // Dropdown Values
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedCareRequestId;
  String? _selectedCareType;
  String? _selectedPriority;
  String? _selectedFrequency;

  // Date Values
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Available Options
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _careRequests = [];
  bool _loadingCareRequests = false;
  bool _loadingDropdowns = true;

  final List<String> _careTypes = [
    'General Care',
    'Elderly Care',
    'Post-Surgical Care',
    'Pediatric Care',
    'Chronic Disease Management',
    'Palliative Care',
    'Rehabilitation Care',
  ];
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _frequencies = ['Daily', 'Weekly', 'Twice Weekly', 'Monthly', 'As Needed', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customFrequencyController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownData() async {
    try {
      final doctors = await _carePlanService.getDoctors();
      final patients = await _carePlanService.getPatients();

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _patients = patients;
          _loadingDropdowns = false;
        });

        debugPrint('✅ Loaded ${_doctors.length} doctors and ${_patients.length} patients');
      }
    } catch (e) {
      debugPrint('❌ Error loading dropdown data: $e');
      if (mounted) {
        setState(() {
          _loadingDropdowns = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Could not load all options. Please try again.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9A00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadCareRequestsForPatient(String patientId) async {
    if (patientId.isEmpty) {
      setState(() {
        _careRequests = [];
      });
      return;
    }

    setState(() {
      _loadingCareRequests = true;
    });

    try {
      final careRequests = await _carePlanService.getPatientCareRequests(int.parse(patientId));

      if (mounted) {
        setState(() {
          _careRequests = careRequests;
          _loadingCareRequests = false;
        });

        debugPrint('✅ Loaded ${_careRequests.length} care requests for patient $patientId');
      }
    } catch (e) {
      debugPrint('❌ Error loading care requests: $e');
      if (mounted) {
        setState(() {
          _careRequests = [];
          _loadingCareRequests = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? _startDate.add(const Duration(days: 30))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _transformCareTypeToBackend(String uiValue) {
    if (uiValue.isEmpty) return '';
    return uiValue.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  String _transformPriorityToBackend(String uiValue) {
    if (uiValue.isEmpty) return '';
    return uiValue.toLowerCase();
  }

  String _transformFrequencyToBackend(String uiValue) {
    if (uiValue.isEmpty) return '';

    final normalized = uiValue.toLowerCase().trim();

    switch (normalized) {
      case 'daily':
        return 'once_daily';
      case 'twice weekly':
      case 'bi-weekly':
      case 'bi weekly':
      case 'biweekly':
        return 'twice_weekly';
      case 'as needed':
        return 'as_needed';
      case 'weekly':
        return 'weekly';
      case 'monthly':
        return 'monthly';
      case 'custom':
        // Return the custom frequency value entered by user
        final customValue = _customFrequencyController.text.trim();
        return customValue.isNotEmpty ? customValue : 'custom';
      default:
        return normalized.replaceAll(' ', '_').replaceAll('-', '_');
    }
  }

  Future<void> _createCarePlan() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatientId == null) {
        _showErrorSnackBar('Please select a patient');
        return;
      }
      if (_selectedCareType == null) {
        _showErrorSnackBar('Please select a care type');
        return;
      }
      if (_selectedPriority == null) {
        _showErrorSnackBar('Please select a priority');
        return;
      }
      if (_selectedFrequency == null) {
        _showErrorSnackBar('Please select a frequency');
        return;
      }
      if (_selectedFrequency == 'Custom' && _customFrequencyController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter a custom frequency');
        return;
      }

      setState(() => _isSaving = true);

      try {
        final startDateFormatted = _formatDateForApi(_startDate);
        final endDateFormatted = _endDate != null ? _formatDateForApi(_endDate!) : null;

        final careTypeBackend = _transformCareTypeToBackend(_selectedCareType!);
        final priorityBackend = _transformPriorityToBackend(_selectedPriority!);
        final frequencyBackend = _transformFrequencyToBackend(_selectedFrequency!);

        debugPrint('📤 Creating care plan - Transforming values:');
        debugPrint('   Care Type: "$_selectedCareType" → "$careTypeBackend"');
        debugPrint('   Priority: "$_selectedPriority" → "$priorityBackend"');
        debugPrint('   Frequency: "$_selectedFrequency" → "$frequencyBackend"');
        debugPrint('   Care Request ID: $_selectedCareRequestId');

        await _carePlanService.createCarePlan(
          patientId: int.parse(_selectedPatientId!),
          doctorId: _selectedDoctorId != null ? int.parse(_selectedDoctorId!) : null,
          careRequestId: _selectedCareRequestId != null ? int.parse(_selectedCareRequestId!) : null,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          careType: careTypeBackend,
          priority: priorityBackend,
          startDate: startDateFormatted,
          endDate: endDateFormatted,
          frequency: frequencyBackend,
          careTasks: [],
        );

        if (mounted) {
          setState(() => _isSaving = false);
          _showSuccessSnackBar('Care plan created successfully!');
          Navigator.pop(context);
          widget.onSuccess();
        }
      } on CarePlanException catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);

          String errorMessage = e.message;
          if (e.errors != null && e.errors!.isNotEmpty) {
            final firstError = e.errors!.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            } else {
              errorMessage = firstError.toString();
            }
          }

          _showErrorSnackBar(errorMessage);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showErrorSnackBar('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loadingDropdowns
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Basic Information'),
                            const SizedBox(height: 16),
                            _buildBasicInformation(),
                            const SizedBox(height: 24),

                            _buildSectionTitle('Care Details'),
                            const SizedBox(height: 16),
                            _buildCareDetails(),
                            const SizedBox(height: 24),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
            _buildFooterButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Care Plan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Add a new care plan for a patient',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildBasicInformation() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SearchableDropdown(
                label: 'Patient *',
                value: _selectedPatientId,
                items: _patients.map((p) {
                  final id = p['id'];
                  final name = p['name'];
                  return {
                    'value': id?.toString() ?? '',
                    'label': name?.toString() ?? 'Unknown',
                  };
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPatientId = value;
                    _selectedCareRequestId = null;
                    _careRequests = [];
                  });
                  if (value != null && value.isNotEmpty) {
                    _loadCareRequestsForPatient(value);
                  }
                },
                enabled: !_isSaving,
                hintText: 'Search patients...',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SearchableDropdown(
                label: 'Doctor (Optional)',
                value: _selectedDoctorId,
                items: _doctors.map((d) {
                  final id = d['id'];
                  final name = d['name'];
                  return {
                    'value': id?.toString() ?? '',
                    'label': name?.toString() ?? 'Unknown',
                  };
                }).toList(),
                onChanged: (value) => setState(() => _selectedDoctorId = value),
                enabled: !_isSaving,
                hintText: 'Search doctors...',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Care Request Dropdown
        _buildDropdownField(
          label: 'Care Request (Optional)',
          value: _selectedCareRequestId,
          items: _careRequests.map((cr) {
            final id = cr['id'];
            final displayText = cr['display_text'];
            return {
              'value': id?.toString() ?? '',
              'label': displayText?.toString() ?? 'Request #$id',
            };
          }).toList(),
          onChanged: (value) => setState(() => _selectedCareRequestId = value),
          isLoading: _loadingCareRequests,
          disabled: _selectedPatientId == null || _isSaving,
          helperText: _selectedPatientId == null
              ? 'Select a patient first'
              : _careRequests.isEmpty && !_loadingCareRequests
                  ? 'No available care requests for this patient'
                  : null,
        ),

        const SizedBox(height: 16),
        _buildTextField(
          label: 'Care Plan Title *',
          controller: _titleController,
          hint: 'Enter care plan title',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a care plan title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Description *',
          controller: _descriptionController,
          hint: 'Describe the care plan objectives and overview',
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCareDetails() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: 'Care Type *',
                value: _selectedCareType,
                items: _careTypes.map((type) => {
                  'value': type,
                  'label': type,
                }).toList(),
                onChanged: (value) => setState(() => _selectedCareType = value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField(
                label: 'Priority *',
                value: _selectedPriority,
                items: _priorities.map((priority) => {
                  'value': priority,
                  'label': priority,
                }).toList(),
                onChanged: (value) => setState(() => _selectedPriority = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date *',
                date: _startDate,
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'End Date (Optional)',
                date: _endDate,
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Frequency *',
          value: _selectedFrequency,
          items: _frequencies.map((freq) => {
            'value': freq,
            'label': freq,
          }).toList(),
          onChanged: (value) => setState(() {
            _selectedFrequency = value;
            if (value != 'Custom') {
              _customFrequencyController.clear();
            }
          }),
        ),
        if (_selectedFrequency == 'Custom') ...[
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Custom Frequency *',
            controller: _customFrequencyController,
            hint: 'Enter custom frequency (e.g., Every 3 days)',
            validator: (value) {
              if (_selectedFrequency == 'Custom' && (value == null || value.isEmpty)) {
                return 'Please enter custom frequency';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          enabled: !_isSaving,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    bool isLoading = false,
    bool disabled = false,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: (disabled || _isSaving) ? Colors.grey.shade200 : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      helperText ?? 'Select ${label.replaceAll(' *', '').replaceAll(' (Optional)', '')}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                    items: items.isEmpty
                        ? null
                        : items.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['value'],
                              child: Text(
                                item['label'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                    onChanged: (disabled || _isSaving) ? null : onChanged,
                  ),
                ),
        ),
        if (helperText != null && !isLoading) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isSaving ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSaving ? Colors.grey.shade200 : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}'
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null ? const Color(0xFF1A1A1A) : Colors.grey.shade400,
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledForegroundColor: Colors.grey.shade400,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isSaving ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSaving
                      ? [Colors.grey.shade400, Colors.grey.shade400]
                      : [AppColors.primaryGreen, const Color(0xFF25B5A8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isSaving ? [] : [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createCarePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create Care Plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
