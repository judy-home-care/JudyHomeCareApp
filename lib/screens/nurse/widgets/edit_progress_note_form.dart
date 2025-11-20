import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../services/patients_assessments/progress_note_service.dart';
import '../../../models/patients_assessments/progress_note_models.dart';
import '../../../models/patients/nurse_patient_models.dart';

// ==================== EDIT PROGRESS NOTE FORM ====================
class EditProgressNoteForm extends StatefulWidget {
  final PatientDetail patientDetail;
  final ProgressNote progressNote;

  const EditProgressNoteForm({
    Key? key,
    required this.patientDetail,
    required this.progressNote,
  }) : super(key: key);

  @override
  State<EditProgressNoteForm> createState() => _EditProgressNoteFormState();
}

class _EditProgressNoteFormState extends State<EditProgressNoteForm> {
  final _formKey = GlobalKey<FormState>();
  final _progressNoteService = ProgressNoteService();
  bool _isSaving = false;
  
  late DateTime _visitDate;
  late TimeOfDay _visitTime;
  
  // Required Vital Signs Controllers
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respirationController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _spo2Controller = TextEditingController();
  
  bool _medicationAdministered = false;
  final _medicationDetailsController = TextEditingController();
  bool _woundCare = false;
  final _woundCareDetailsController = TextEditingController();
  bool _physiotherapy = false;
  final _physiotherapyDetailsController = TextEditingController();
  bool _nutritionSupport = false;
  final _nutritionDetailsController = TextEditingController();
  bool _hygieneCare = false;
  final _hygieneDetailsController = TextEditingController();
  bool _counseling = false;
  final _counselingDetailsController = TextEditingController();
  bool _otherInterventions = false;
  final _otherInterventionsController = TextEditingController();
  
  String? _expandedIntervention;
  
  // Required Observations Fields
  late String _generalCondition;
  late int _painLevel;
  final _woundStatusController = TextEditingController();
  final _observationsController = TextEditingController();
  
  final _educationProvidedController = TextEditingController();
  final _familyConcernsController = TextEditingController();
  
  final _nextVisitPlanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populateExistingData();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _pulseController.dispose();
    _respirationController.dispose();
    _bloodPressureController.dispose();
    _spo2Controller.dispose();
    _medicationDetailsController.dispose();
    _woundCareDetailsController.dispose();
    _physiotherapyDetailsController.dispose();
    _nutritionDetailsController.dispose();
    _hygieneDetailsController.dispose();
    _counselingDetailsController.dispose();
    _otherInterventionsController.dispose();
    _woundStatusController.dispose();
    _observationsController.dispose();
    _educationProvidedController.dispose();
    _familyConcernsController.dispose();
    _nextVisitPlanController.dispose();
    super.dispose();
  }

  void _populateExistingData() {
    // Parse visit date and time
    try {
      if (widget.progressNote.visitDate != null) {
        _visitDate = DateTime.parse(widget.progressNote.visitDate!);
      } else {
        _visitDate = DateTime.now();
      }
    } catch (e) {
      _visitDate = DateTime.now();
      debugPrint('Error parsing visit date: $e');
    }

    try {
      if (widget.progressNote.visitTime != null) {
        final timeParts = widget.progressNote.visitTime!.split(':');
        _visitTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      } else {
        _visitTime = TimeOfDay.now();
      }
    } catch (e) {
      _visitTime = TimeOfDay.now();
      debugPrint('Error parsing visit time: $e');
    }
    
    // Populate vitals
    if (widget.progressNote.vitals != null) {
      final vitals = widget.progressNote.vitals!;
      _temperatureController.text = vitals['temperature']?.toString() ?? '';
      _pulseController.text = vitals['pulse']?.toString() ?? '';
      _respirationController.text = vitals['respiration']?.toString() ?? '';
      _bloodPressureController.text = vitals['blood_pressure']?.toString() ?? '';
      _spo2Controller.text = vitals['spo2']?.toString() ?? '';
    }
    
    // Populate interventions
    if (widget.progressNote.interventions != null) {
      final interventions = widget.progressNote.interventions!;
      
      _medicationAdministered = interventions['medication_administered'] == true;
      _medicationDetailsController.text = interventions['medication_details']?.toString() ?? '';
      
      _woundCare = interventions['wound_care'] == true;
      _woundCareDetailsController.text = interventions['wound_care_details']?.toString() ?? '';
      
      _physiotherapy = interventions['physiotherapy'] == true;
      _physiotherapyDetailsController.text = interventions['physiotherapy_details']?.toString() ?? '';
      
      _nutritionSupport = interventions['nutrition_support'] == true;
      _nutritionDetailsController.text = interventions['nutrition_details']?.toString() ?? '';
      
      _hygieneCare = interventions['hygiene_care'] == true;
      _hygieneDetailsController.text = interventions['hygiene_details']?.toString() ?? '';
      
      _counseling = interventions['counseling'] == true;
      _counselingDetailsController.text = interventions['counseling_details']?.toString() ?? '';
      
      _otherInterventions = interventions['other_interventions'] == true;
      _otherInterventionsController.text = interventions['other_details']?.toString() ?? '';
    }
    
    // Populate observations
    _generalCondition = widget.progressNote.generalCondition ?? 'Stable';
    // Capitalize first letter to match dropdown values
    if (_generalCondition.isNotEmpty) {
      _generalCondition = _generalCondition[0].toUpperCase() + _generalCondition.substring(1).toLowerCase();
    }
    // Handle special cases
    if (_generalCondition.toLowerCase() == 'improved') {
      _generalCondition = 'Improving';
    } else if (_generalCondition.toLowerCase() == 'deteriorating') {
      _generalCondition = 'Declining';
    }
    
    _painLevel = widget.progressNote.painLevel ?? 0;
    _woundStatusController.text = widget.progressNote.woundStatus ?? '';
    _observationsController.text = widget.progressNote.otherObservations ?? '';
    
    // Populate communication
    _educationProvidedController.text = widget.progressNote.educationProvided ?? '';
    _familyConcernsController.text = widget.progressNote.familyConcerns ?? '';
    
    // Populate plan
    _nextVisitPlanController.text = widget.progressNote.nextSteps ?? '';
  }

  void _toggleInterventionExpansion(String intervention, bool isChecked) {
    setState(() {
      if (isChecked) {
        _expandedIntervention = intervention;
      } else {
        if (_expandedIntervention == intervention) {
          _expandedIntervention = null;
        }
      }
    });
  }

  void _toggleExpansionOnly(String intervention) {
    setState(() {
      if (_expandedIntervention == intervention) {
        _expandedIntervention = null;
      } else {
        _expandedIntervention = intervention;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    if (picked != null && picked != _visitDate) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
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
    if (picked != null && picked != _visitTime) {
      setState(() {
        _visitTime = picked;
      });
    }
  }

  Future<void> _updateNote() async {
    if (_formKey.currentState!.validate()) {
      if (_temperatureController.text.isEmpty ||
          _pulseController.text.isEmpty ||
          _respirationController.text.isEmpty ||
          _bloodPressureController.text.isEmpty ||
          _spo2Controller.text.isEmpty) {
        _showErrorSnackBar('All vital signs fields are required');
        return;
      }

      final vitals = _buildVitalsObject();
      if (vitals != null) {
        final vitalsError = _progressNoteService.validateVitals(vitals);
        if (vitalsError != null) {
          _showErrorSnackBar(vitalsError);
          return;
        }
      }

      final painError = _progressNoteService.validatePainLevel(_painLevel);
      if (painError != null) {
        _showErrorSnackBar(painError);
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final request = CreateProgressNoteRequest(
          visitDate: _progressNoteService.formatDateForApi(_visitDate),
          visitTime: _progressNoteService.formatTimeForApi(
            _visitTime.hour,
            _visitTime.minute,
          ),
          vitals: vitals,
          interventions: _buildInterventionsObject(),
          generalCondition: _generalCondition,
          painLevel: _painLevel,
          woundStatus: _woundStatusController.text.trim().isEmpty
              ? null
              : _woundStatusController.text.trim(),
          otherObservations: _observationsController.text.trim().isEmpty
              ? null
              : _observationsController.text.trim(),
          educationProvided: _educationProvidedController.text.trim().isEmpty
              ? null
              : _educationProvidedController.text.trim(),
          familyConcerns: _familyConcernsController.text.trim().isEmpty
              ? null
              : _familyConcernsController.text.trim(),
          nextSteps: _nextVisitPlanController.text.trim().isEmpty
              ? null
              : _nextVisitPlanController.text.trim(),
        );

        final response = await _progressNoteService.updateProgressNote(
          widget.progressNote.id!,
          request,
        );

        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          _showSuccessSnackBar(response.message);
          Navigator.pop(context, true);
        }
      } on ProgressNoteException catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          if (e.errors != null && e.errors!.isNotEmpty) {
            final errorMessages = <String>[];
            e.errors!.forEach((key, value) {
              if (value is List) {
                errorMessages.addAll(value.map((e) => e.toString()));
              } else {
                errorMessages.add(value.toString());
              }
            });
            _showErrorSnackBar(errorMessages.join('\n'));
          } else {
            _showErrorSnackBar(e.message);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          _showErrorSnackBar('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  ProgressNoteVitals? _buildVitalsObject() {
    return ProgressNoteVitals(
      temperature: _temperatureController.text.isEmpty
          ? null
          : double.tryParse(_temperatureController.text),
      pulse: _pulseController.text.isEmpty
          ? null
          : int.tryParse(_pulseController.text),
      respiration: _respirationController.text.isEmpty
          ? null
          : int.tryParse(_respirationController.text),
      bloodPressure: _bloodPressureController.text.isEmpty
          ? null
          : _bloodPressureController.text.trim(),
      spo2: _spo2Controller.text.isEmpty
          ? null
          : int.tryParse(_spo2Controller.text),
    );
  }

  ProgressNoteInterventions? _buildInterventionsObject() {
    final hasAnyIntervention = _medicationAdministered ||
        _woundCare ||
        _physiotherapy ||
        _nutritionSupport ||
        _hygieneCare ||
        _counseling ||
        _otherInterventions;

    if (!hasAnyIntervention) return null;

    return ProgressNoteInterventions(
      medicationAdministered: _medicationAdministered,
      medicationDetails: _medicationAdministered && _medicationDetailsController.text.isNotEmpty
          ? _medicationDetailsController.text.trim()
          : null,
      woundCare: _woundCare,
      woundCareDetails: _woundCare && _woundCareDetailsController.text.isNotEmpty
          ? _woundCareDetailsController.text.trim()
          : null,
      physiotherapy: _physiotherapy,
      physiotherapyDetails: _physiotherapy && _physiotherapyDetailsController.text.isNotEmpty
          ? _physiotherapyDetailsController.text.trim()
          : null,
      nutritionSupport: _nutritionSupport,
      nutritionDetails: _nutritionSupport && _nutritionDetailsController.text.isNotEmpty
          ? _nutritionDetailsController.text.trim()
          : null,
      hygieneCare: _hygieneCare,
      hygieneDetails: _hygieneCare && _hygieneDetailsController.text.isNotEmpty
          ? _hygieneDetailsController.text.trim()
          : null,
      counseling: _counseling,
      counselingDetails: _counseling && _counselingDetailsController.text.isNotEmpty
          ? _counselingDetailsController.text.trim()
          : null,
      otherInterventions: _otherInterventions,
      otherDetails: _otherInterventions && _otherInterventionsController.text.isNotEmpty
          ? _otherInterventionsController.text.trim()
          : null,
    );
  }

  void _showSuccessSnackBar(String message) {
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
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_note,
                          color: AppColors.primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Progress Note',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'For ${widget.patientDetail.name}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visit Date and Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Visit Date *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20, color: AppColors.primaryGreen),
                                  const SizedBox(width: 12),
                                  Text(
                                    DateFormat('MM/dd/yyyy').format(_visitDate),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Visit Time *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20, color: AppColors.primaryGreen),
                                  const SizedBox(width: 12),
                                  Text(
                                    _visitTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Vital Signs
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Vital Signs (All Required)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildRequiredNumberField(
                              label: 'Temperature (°C) *',
                              controller: _temperatureController,
                              hint: '36.5',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRequiredNumberField(
                              label: 'Pulse (bpm) *',
                              controller: _pulseController,
                              hint: '72',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildRequiredNumberField(
                              label: 'Respiration (/min) *',
                              controller: _respirationController,
                              hint: '16',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRequiredTextField(
                              label: 'Blood Pressure *',
                              controller: _bloodPressureController,
                              hint: '120/80',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildRequiredNumberField(
                        label: 'SpO₂ (%) *',
                        controller: _spo2Controller,
                        hint: '98',
                      ),
                      const SizedBox(height: 24),
                      
                      // Interventions
                      Row(
                        children: [
                          const Icon(Icons.medical_services, color: Color(0xFFFF9A00), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Interventions Provided',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      _buildExpandableCheckbox(
                        label: 'Medication Administered',
                        value: _medicationAdministered,
                        interventionKey: 'medication',
                        controller: _medicationDetailsController,
                        hint: 'List medications administered...',
                        onChanged: (value) {
                          setState(() {
                            _medicationAdministered = value!;
                          });
                          _toggleInterventionExpansion('medication', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Wound Care',
                        value: _woundCare,
                        interventionKey: 'wound',
                        controller: _woundCareDetailsController,
                        hint: 'Describe wound care provided...',
                        onChanged: (value) {
                          setState(() {
                            _woundCare = value!;
                          });
                          _toggleInterventionExpansion('wound', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Physiotherapy/Exercise',
                        value: _physiotherapy,
                        interventionKey: 'physio',
                        controller: _physiotherapyDetailsController,
                        hint: 'Describe exercises or therapy provided...',
                        onChanged: (value) {
                          setState(() {
                            _physiotherapy = value!;
                          });
                          _toggleInterventionExpansion('physio', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Nutrition/Feeding Support',
                        value: _nutritionSupport,
                        interventionKey: 'nutrition',
                        controller: _nutritionDetailsController,
                        hint: 'Describe nutritional support provided...',
                        onChanged: (value) {
                          setState(() {
                            _nutritionSupport = value!;
                          });
                          _toggleInterventionExpansion('nutrition', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Hygiene/Personal Care',
                        value: _hygieneCare,
                        interventionKey: 'hygiene',
                        controller: _hygieneDetailsController,
                        hint: 'Describe hygiene care provided...',
                        onChanged: (value) {
                          setState(() {
                            _hygieneCare = value!;
                          });
                          _toggleInterventionExpansion('hygiene', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Counseling/Education',
                        value: _counseling,
                        interventionKey: 'counseling',
                        controller: _counselingDetailsController,
                        hint: 'Describe counseling or education provided...',
                        onChanged: (value) {
                          setState(() {
                            _counseling = value!;
                          });
                          _toggleInterventionExpansion('counseling', value!);
                        },
                      ),
                      
                      _buildExpandableCheckbox(
                        label: 'Other Interventions',
                        value: _otherInterventions,
                        interventionKey: 'other',
                        controller: _otherInterventionsController,
                        hint: 'Describe other interventions...',
                        onChanged: (value) {
                          setState(() {
                            _otherInterventions = value!;
                          });
                          _toggleInterventionExpansion('other', value!);
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Observations
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye, color: Color(0xFF2196F3), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Observations/Findings (Required)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'General Condition *',
                              value: _generalCondition,
                              items: ['Stable', 'Improving', 'Declining', 'Critical'],
                              onChanged: (value) {
                                setState(() {
                                  _generalCondition = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pain Level (0-10) *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _painLevel.toString(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (_painLevel < 10) {
                                                setState(() {
                                                  _painLevel++;
                                                });
                                              }
                                            },
                                            child: const Icon(
                                              Icons.arrow_drop_up,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              if (_painLevel > 0) {
                                                setState(() {
                                                  _painLevel--;
                                                });
                                              }
                                            },
                                            child: const Icon(
                                              Icons.arrow_drop_down,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        label: 'Wound Status (if any)',
                        controller: _woundStatusController,
                        hint: 'Describe wound status, healing progress, etc...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        label: 'Other Significant Observations',
                        controller: _observationsController,
                        hint: 'Note any other significant observations...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Communication
                      Row(
                        children: [
                          const Icon(Icons.people, color: Color(0xFF6C63FF), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Family/Client Communication',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      _buildTextField(
                        label: 'Education Provided',
                        controller: _educationProvidedController,
                        hint: 'Describe education provided to patient/family...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        label: 'Concerns Raised by Family/Client',
                        controller: _familyConcernsController,
                        hint: 'Note any concerns raised by family or client...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Plan
                      Row(
                        children: [
                          const Icon(Icons.event_note, color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Plan / Next Steps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      _buildTextField(
                        label: 'Plan for Next Visit',
                        controller: _nextVisitPlanController,
                        hint: 'Outline plans for the next visit, follow-up care, adjustments needed...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF666666),
                                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _updateNote,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.5),
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
                                      'Update Note',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
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

  // Helper Widgets (same as DailyProgressNoteForm)
  
  Widget _buildExpandableCheckbox({
    required String label,
    required bool value,
    required String interventionKey,
    required TextEditingController controller,
    required String hint,
    required void Function(bool?) onChanged,
  }) {
    final isExpanded = _expandedIntervention == interventionKey;
    
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: value ? AppColors.primaryGreen.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF1A1A1A),
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: value,
                  onChanged: onChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primaryGreen,
                  contentPadding: const EdgeInsets.only(left: 0, right: 8),
                ),
              ),
              if (value)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryGreen,
                  ),
                  onPressed: () => _toggleExpansionOnly(interventionKey),
                ),
            ],
          ),
        ),
        if (value && isExpanded) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 16, bottom: 12),
            child: TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredNumberField({
    required String label,
    required TextEditingController controller,
    required String hint,
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
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}