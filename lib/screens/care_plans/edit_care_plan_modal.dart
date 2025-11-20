import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/care_plans/care_plan_service.dart';
import '../../models/care_plans/care_plan_models.dart';
import '../../widgets/searchable_dropdown.dart';

class EditCarePlanModal extends StatefulWidget {
  final CarePlan carePlan;
  final VoidCallback onSuccess;
  final List<CarePlan> existingCarePlans;

  const EditCarePlanModal({
    Key? key,
    required this.carePlan,
    required this.onSuccess,
    required this.existingCarePlans,
  }) : super(key: key);

  @override
  State<EditCarePlanModal> createState() => _EditCarePlanModalState();
}

class _EditCarePlanModalState extends State<EditCarePlanModal> {
  final _formKey = GlobalKey<FormState>();
  final _carePlanService = CarePlanService();
  bool _isSaving = false;
  
  // Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<TextEditingController> _taskControllers;
  
  // Dropdown Values
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedCareRequestId;  // ✅ ADDED
  String? _selectedCareType;
  String? _selectedPriority;
  String? _selectedFrequency;
  
  // Date Values
  late DateTime _startDate;
  DateTime? _endDate;
  
  // Available Options
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _careRequests = [];  // ✅ ADDED
  bool _loadingCareRequests = false;  // ✅ ADDED
  
  final List<String> _careTypes = [
    'General Care',
    'Elderly Care',
    'Post-Surgery Care',
    'Pediatric Care',
    'Chronic Disease Management',
    'Palliative Care',
    'Rehabilitation Care',
  ];
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _frequencies = ['Daily', 'Weekly', 'Bi-weekly', 'Monthly', 'As Needed'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadDropdownData();
  }

  void _initializeControllers() {
    // Initialize text controllers with existing data
    _titleController = TextEditingController(text: widget.carePlan.carePlan);
    _descriptionController = TextEditingController(text: widget.carePlan.description);
    
    // Initialize task controllers with existing tasks
    if (widget.carePlan.careTasks.isNotEmpty) {
      _taskControllers = widget.carePlan.careTasks
          .map((task) => TextEditingController(text: task))
          .toList();
    } else {
      _taskControllers = [TextEditingController()];
    }
    
    // Set dropdown values - TRANSFORM FROM BACKEND TO UI FORMAT
    _selectedPatientId = widget.carePlan.patientId?.toString();
    _selectedDoctorId = widget.carePlan.doctorId?.toString();
    _selectedCareRequestId = widget.carePlan.careRequestId?.toString();  // ✅ ADDED
    _selectedCareType = _transformCareTypeFromBackend(widget.carePlan.careType);
    _selectedPriority = _transformPriorityFromBackend(widget.carePlan.priority);
    _selectedFrequency = _transformFrequencyFromBackend(widget.carePlan.frequency);
    
    // Debug logging
    debugPrint('🔄 Initializing Edit Modal:');
    debugPrint('   Backend Care Type: "${widget.carePlan.careType}" → UI: "$_selectedCareType"');
    debugPrint('   Backend Priority: "${widget.carePlan.priority}" → UI: "$_selectedPriority"');
    debugPrint('   Backend Frequency: "${widget.carePlan.frequency}" → UI: "$_selectedFrequency"');
    debugPrint('   Care Request ID: $_selectedCareRequestId');
    
    // Set dates
    _startDate = widget.carePlan.startDate != null 
        ? _parseDate(widget.carePlan.startDate!) 
        : DateTime.now();
    _endDate = widget.carePlan.endDate != null 
        ? _parseDate(widget.carePlan.endDate!) 
        : null;
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
      default:
        return normalized.replaceAll(' ', '_').replaceAll('-', '_');
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateStr');
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
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
        });
        
        debugPrint('✅ Loaded ${_doctors.length} doctors and ${_patients.length} patients');
        
        // ✅ Load care requests for the current patient
        if (_selectedPatientId != null) {
          _loadCareRequestsForPatient(_selectedPatientId!);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading dropdown data: $e');
      _loadDropdownDataFromExistingCarePlans();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Could not load all options. Using available data.',
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

  // ✅ ADDED THIS METHOD
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
      
      // ✅ Include the currently assigned care request even if it has a care plan
      if (_selectedCareRequestId != null && 
          !careRequests.any((cr) => cr['id'].toString() == _selectedCareRequestId)) {
        careRequests.insert(0, {
          'id': int.parse(_selectedCareRequestId!),
          'display_text': 'Request #$_selectedCareRequestId (Current)',
          'service_type': 'Current Care Request',
          'status': 'assigned',
        });
      }
      
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

  void _loadDropdownDataFromExistingCarePlans() {
    final seenPatientIds = <int>{};
    final seenDoctorIds = <int>{};
    final patients = <Map<String, dynamic>>[];
    final doctors = <Map<String, dynamic>>[];

    for (var carePlan in widget.existingCarePlans) {
      if (carePlan.patientId != null && 
          carePlan.patient.isNotEmpty && 
          !seenPatientIds.contains(carePlan.patientId)) {
        seenPatientIds.add(carePlan.patientId!);
        patients.add({
          'id': carePlan.patientId!,
          'name': carePlan.patient,
        });
      }

      if (carePlan.doctorId != null && 
          carePlan.doctor.isNotEmpty && 
          !seenDoctorIds.contains(carePlan.doctorId)) {
        seenDoctorIds.add(carePlan.doctorId!);
        doctors.add({
          'id': carePlan.doctorId!,
          'name': carePlan.doctor,
        });
      }
    }

    patients.sort((a, b) {
      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });
    
    doctors.sort((a, b) {
      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });

    if (mounted) {
      setState(() {
        _patients = patients;
        _doctors = doctors;
      });
      debugPrint('⚠️ Using fallback data: ${_doctors.length} doctors, ${_patients.length} patients');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
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

  Future<void> _updateCarePlan() async {
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

      final tasks = _taskControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      
      if (tasks.isEmpty) {
        _showErrorSnackBar('Please add at least one care task');
        return;
      }

      setState(() => _isSaving = true);

      try {
        final startDateFormatted = _formatDateForApi(_startDate);
        final endDateFormatted = _endDate != null ? _formatDateForApi(_endDate!) : null;

        final careTypeBackend = _transformCareTypeToBackend(_selectedCareType!);
        final priorityBackend = _transformPriorityToBackend(_selectedPriority!);
        final frequencyBackend = _transformFrequencyToBackend(_selectedFrequency!);

        debugPrint('📤 Updating care plan - Transforming values:');
        debugPrint('   Care Type: "$_selectedCareType" → "$careTypeBackend"');
        debugPrint('   Priority: "$_selectedPriority" → "$priorityBackend"');
        debugPrint('   Frequency: "$_selectedFrequency" → "$frequencyBackend"');
        debugPrint('   Care Request ID: $_selectedCareRequestId');

        final response = await _carePlanService.updateCarePlan(
          carePlanId: widget.carePlan.id,
          patientId: int.parse(_selectedPatientId!),
          doctorId: _selectedDoctorId != null ? int.parse(_selectedDoctorId!) : null,
          careRequestId: _selectedCareRequestId != null ? int.parse(_selectedCareRequestId!) : null,  // ✅ ADDED
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          careType: careTypeBackend,
          priority: priorityBackend,
          startDate: startDateFormatted,
          endDate: endDateFormatted,
          frequency: frequencyBackend,
          careTasks: tasks,
        );

        if (mounted) {
          setState(() => _isSaving = false);
          _showSuccessSnackBar('Care plan updated successfully!');
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
              child: Form(
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
                      
                      _buildSectionTitle('Care Tasks'),
                      const SizedBox(height: 16),
                      _buildCareTasks(),
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
                child: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Care Plan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'ID: #${widget.carePlan.id}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
                label: 'Doctor',
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
        
        // ✅ CARE REQUEST DROPDOWN
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
                label: 'End Date',
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
          onChanged: (value) => setState(() => _selectedFrequency = value),
        ),
      ],
    );
  }

  Widget _buildCareTasks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ..._taskControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Enter care task description...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_taskControllers.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _taskControllers.removeAt(index);
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFFF4757),
                        size: 22,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          GestureDetector(
            onTap: () {
              setState(() {
                _taskControllers.add(TextEditingController());
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryGreen,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add Another Task',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                onPressed: _isSaving ? null : _updateCarePlan,
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
                        'Update Care Plan',
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

  // ==================== TRANSFORMATION METHODS ====================
  
  String _transformCareTypeFromBackend(String backendValue) {
    if (backendValue.isEmpty) return '';
    
    final normalized = backendValue.toLowerCase().trim();
    if (normalized == 'post_surgery_care' || normalized == 'post-surgery-care') {
      return 'Post-Surgery Care';
    }
    
    return backendValue
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _transformPriorityFromBackend(String backendValue) {
    if (backendValue.isEmpty) return '';
    
    return backendValue[0].toUpperCase() + backendValue.substring(1).toLowerCase();
  }

  String _transformFrequencyFromBackend(String backendValue) {
    if (backendValue.isEmpty) return '';
    
    final normalized = backendValue.toLowerCase().trim();
    
    switch (normalized) {
      case 'once_daily':
      case 'daily':
        return 'Daily';
        
      case 'twice_weekly':
      case 'bi-weekly':
      case 'bi_weekly':
      case 'biweekly':
        return 'Bi-weekly';
        
      case 'as_needed':
      case 'as-needed':
        return 'As Needed';
        
      case 'weekly':
        return 'Weekly';
        
      case 'monthly':
        return 'Monthly';
        
      default:
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }
}