import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/patients_assessments/medical_assessment_models.dart';
import '../../models/patients/nurse_patient_models.dart';
import '../../services/patients_assessments/progress_note_service.dart';
import '../../utils/app_colors.dart';
import '../../models/care_request/care_request_models.dart';

class NurseMedicalAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  final CareRequest? careRequest;
  
  const NurseMedicalAssessmentScreen({
    Key? key,
    required this.nurseData,
    this.careRequest,
  }) : super(key: key);

  @override
  State<NurseMedicalAssessmentScreen> createState() => _NurseMedicalAssessmentScreenState();
}

class _NurseMedicalAssessmentScreenState extends State<NurseMedicalAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ProgressNoteService = ProgressNoteService();
  
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int get _totalSteps => widget.careRequest != null ? 3 : 4;
  
  bool _isLoading = false;
  bool _isLoadingPatients = false;
  bool _isLoadingLocation = false;
  List<PatientOption> _patients = [];
  
  String? _locationName;
  String? _locationDetails;
  
  bool _selectingNewPatient = true;
  int? _selectedPatientId;

  bool get _isNewPatient => widget.careRequest == null ? _selectingNewPatient : false;

  
  final _patientFirstNameController = TextEditingController();
  final _patientLastNameController = TextEditingController();
  final _patientPhoneController = TextEditingController();
  final _patientDoBController = TextEditingController();
  String _patientGender = 'male';
  final _patientGhanaCardController = TextEditingController();
  
  final _physicalAddressController = TextEditingController();
  final _occupationController = TextEditingController();
  final _religionController = TextEditingController();
  
  final _emergencyContact1NameController = TextEditingController();
  final _emergencyContact1RelationshipController = TextEditingController();
  final _emergencyContact1PhoneController = TextEditingController();
  final _emergencyContact2NameController = TextEditingController();
  final _emergencyContact2RelationshipController = TextEditingController();
  final _emergencyContact2PhoneController = TextEditingController();
  
  final _presentingConditionController = TextEditingController();
  final _pastMedicalHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  final _specialNeedsController = TextEditingController();
  
  String _generalCondition = 'stable';
  String _hydrationStatus = 'adequate';
  String _nutritionStatus = 'adequate';
  String _mobilityStatus = 'independent';
  bool _hasWounds = false;
  final _woundDescriptionController = TextEditingController();
  double _painLevel = 0;
  
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  
  final _nursingImpressionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _getCurrentLocation();

    if (widget.careRequest != null) {
      _prePopulateFromCareRequest();
    }
    
    _physicalAddressController.addListener(() {
      if (_physicalAddressController.text.isEmpty && _locationName != null) {
        setState(() {
          _locationName = null;
          _locationDetails = null;
        });
      }
    });
  }

  void _prePopulateFromCareRequest() {
    final request = widget.careRequest!;
    
    _physicalAddressController.text = request.serviceAddress;
    _selectedPatientId = request.patientId;
    
    debugPrint('📋 Pre-populated from care request:');
    debugPrint('   Patient ID: $_selectedPatientId');
    debugPrint('   Address: ${_physicalAddressController.text}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _patientFirstNameController.dispose();
    _patientLastNameController.dispose();
    _patientPhoneController.dispose();
    _patientDoBController.dispose();
    _patientGhanaCardController.dispose();
    _physicalAddressController.dispose();
    _occupationController.dispose();
    _religionController.dispose();
    _emergencyContact1NameController.dispose();
    _emergencyContact1RelationshipController.dispose();
    _emergencyContact1PhoneController.dispose();
    _emergencyContact2NameController.dispose();
    _emergencyContact2RelationshipController.dispose();
    _emergencyContact2PhoneController.dispose();
    _presentingConditionController.dispose();
    _pastMedicalHistoryController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    _specialNeedsController.dispose();
    _woundDescriptionController.dispose();
    _temperatureController.dispose();
    _pulseController.dispose();
    _respiratoryRateController.dispose();
    _bloodPressureController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _nursingImpressionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorSnackbar('Location services are disabled. Please enable them.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showErrorSnackbar('Location permission denied.');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showErrorSnackbar('Location permissions are permanently denied.');
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        String fullAddress = addressParts.join(', ');
        
        setState(() {
          _locationName = place.locality ?? place.subLocality ?? place.administrativeArea ?? 'Current Location';
          _locationDetails = place.street ?? place.subLocality ?? place.administrativeArea;
          _physicalAddressController.text = fullAddress.isNotEmpty 
              ? fullAddress 
              : '${position.latitude}, ${position.longitude}';
        });
        
        debugPrint('Location Name: $_locationName');
        debugPrint('Location Details: $_locationDetails');
        debugPrint('Full Address: ${_physicalAddressController.text}');
      } else if (mounted) {
        setState(() {
          _locationName = 'Current Location';
          _locationDetails = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          _physicalAddressController.text = _locationDetails!;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        _showErrorSnackbar('Could not get current location. Please enter manually.');
        setState(() {
          _locationName = null;
          _locationDetails = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoadingPatients = true;
    });

    try {
      final response = await _ProgressNoteService.getNursePatients();
      
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _patients = (response['data'] as List)
              .map((patient) => PatientOption(
                    id: patient['id'] as int,
                    name: patient['name'] as String,
                    ghanaCard: patient['ghanaCard'] as String?,
                    phone: patient['phone'] as String?,
                    age: patient['age'] as int?,
                  ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading patients: $e');
    } finally {
      setState(() {
        _isLoadingPatients = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitAssessment() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Please fill all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = MedicalAssessmentRequest(
        careRequestId: widget.careRequest?.id,
        isNewPatient: widget.careRequest != null ? false : _isNewPatient,
        patientId: widget.careRequest != null 
            ? widget.careRequest!.patientId  
            : (_isNewPatient ? null : _selectedPatientId),
        patientFirstName: widget.careRequest == null && _isNewPatient 
          ? _patientFirstNameController.text 
          : null,
        patientLastName: widget.careRequest == null && _isNewPatient 
          ? _patientLastNameController.text 
          : null,
        patientPhone: _isNewPatient ? _patientPhoneController.text : null,
        patientDateOfBirth: _isNewPatient ? _patientDoBController.text : null,
        patientGender: _isNewPatient ? _patientGender : null,
        patientGhanaCard: _isNewPatient ? _patientGhanaCardController.text : null,
        nurseId: int.parse(widget.nurseData['id'].toString()),
        physicalAddress: _physicalAddressController.text,
        occupation: _occupationController.text.isEmpty ? null : _occupationController.text,
        religion: _religionController.text.isEmpty ? null : _religionController.text,
        emergencyContact1Name: _emergencyContact1NameController.text,
        emergencyContact1Relationship: _emergencyContact1RelationshipController.text,
        emergencyContact1Phone: _emergencyContact1PhoneController.text,
        emergencyContact2Name: _emergencyContact2NameController.text.isEmpty ? null : _emergencyContact2NameController.text,
        emergencyContact2Relationship: _emergencyContact2RelationshipController.text.isEmpty ? null : _emergencyContact2RelationshipController.text,
        emergencyContact2Phone: _emergencyContact2PhoneController.text.isEmpty ? null : _emergencyContact2PhoneController.text,
        presentingCondition: _presentingConditionController.text,
        pastMedicalHistory: _pastMedicalHistoryController.text.isEmpty ? null : _pastMedicalHistoryController.text,
        allergies: _allergiesController.text.isEmpty ? null : _allergiesController.text,
        currentMedications: _currentMedicationsController.text.isEmpty ? null : _currentMedicationsController.text,
        specialNeeds: _specialNeedsController.text.isEmpty ? null : _specialNeedsController.text,
        generalCondition: _generalCondition,
        hydrationStatus: _hydrationStatus,
        nutritionStatus: _nutritionStatus,
        mobilityStatus: _mobilityStatus,
        hasWounds: _hasWounds,
        woundDescription: _hasWounds ? _woundDescriptionController.text : null,
        painLevel: _painLevel.toInt(),
        initialVitals: {
          'temperature': double.parse(_temperatureController.text),
          'pulse': int.parse(_pulseController.text),
          'respiratory_rate': int.parse(_respiratoryRateController.text),
          'blood_pressure': _bloodPressureController.text,
          'spo2': int.parse(_spo2Controller.text),
          'weight': double.parse(_weightController.text),
        },
        initialNursingImpression: _nursingImpressionController.text,
      );

      final response = await _ProgressNoteService.createMedicalAssessment(request);

      if (!mounted) return;

      if (response.success) {
        _showSuccessSnackbar('Medical assessment created successfully!');
        Navigator.of(context).pop(true);
      } else {
        _showErrorSnackbar(response.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to create assessment. Please try again.');
        debugPrint('Error creating assessment: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Medical Assessment',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _buildStepIndicator(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: widget.careRequest != null
                ? [
                    _buildStep2ClientAndEmergencyInfo(),
                    _buildStep3MedicalHistory(),
                    _buildStep4AssessmentAndVitals(),
                  ]
                : [
                    _buildStep1PatientSelection(),
                    _buildStep2ClientAndEmergencyInfo(),
                    _buildStep3MedicalHistory(),
                    _buildStep4AssessmentAndVitals(),
                  ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? const Color(0xFF199A8E)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1PatientSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Patient Selection', 'Step 1 of $_totalSteps'),
          const SizedBox(height: 24),
          
          _buildPatientTypeSelector(),
          const SizedBox(height: 24),
          
          if (_isNewPatient) ...[
            _buildNewPatientForm(),
          ] else ...[
            _buildExistingPatientSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
            onTap: () {
              setState(() {
                _selectingNewPatient = true; 
                _selectedPatientId = null;
              });
            },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isNewPatient ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isNewPatient
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'New Patient',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _isNewPatient ? FontWeight.w600 : FontWeight.w500,
                    color: _isNewPatient ? const Color(0xFF199A8E) : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectingNewPatient = false; 
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isNewPatient ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isNewPatient
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Existing Patient',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: !_isNewPatient ? FontWeight.w600 : FontWeight.w500,
                    color: !_isNewPatient ? const Color(0xFF199A8E) : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPatientForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _patientFirstNameController,
                label: 'First Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (_isNewPatient && (value == null || value.isEmpty)) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _patientLastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (_isNewPatient && (value == null || value.isEmpty)) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: _patientPhoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (_isNewPatient && (value == null || value.isEmpty)) {
              return 'Phone number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: _patientGhanaCardController,
          label: 'Ghana Card Number',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (_isNewPatient && (value == null || value.isEmpty)) {
              return 'Ghana Card is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        _buildDateField(
          controller: _patientDoBController,
          label: 'Date of Birth',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 16),
        
        _buildGenderSelector(),
      ],
    );
  }

  Widget _buildExistingPatientSelector() {
    if (_isLoadingPatients) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
        ),
      );
    }

    if (_patients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No patients found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to "New Patient" to create one',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Patient',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<int>(
            value: _selectedPatientId,
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.person_search_outlined,
                  color: const Color(0xFF199A8E),
                  size: 20,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            hint: const Text('Choose a patient'),
            isExpanded: true,
            items: _patients.map((patient) {
              String patientInfo = patient.name;
              List<String> details = [];
              if (patient.age != null) details.add('${patient.age}yo');
              if (patient.phone != null) details.add(patient.phone!);
              
              if (details.isNotEmpty) {
                patientInfo += ' (${details.join(' • ')})';
              }
              
              return DropdownMenuItem<int>(
                value: patient.id,
                child: Text(
                  patientInfo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPatientId = value;
              });
            },
            validator: (value) {
              if (!_isNewPatient && value == null) {
                return 'Please select a patient';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        
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
              child: _buildGenderOption('Other', 'other', Icons.transgender),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String label, String value, IconData icon) {
    final isSelected = _patientGender == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _patientGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF199A8E).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF199A8E) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF199A8E) : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF199A8E) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2ClientAndEmergencyInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Client & Emergency Info', 'Step 2 of $_totalSteps'),
          const SizedBox(height: 24),
          
          Text(
            'Client Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildPhysicalAddressField(),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _occupationController,
                  label: 'Occupation (Optional)',
                  icon: Icons.work_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _religionController,
                  label: 'Religion (Optional)',
                  icon: Icons.church_outlined,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Emergency Contact 1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _emergencyContact1NameController,
            label: 'Contact Name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Emergency contact name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _emergencyContact1RelationshipController,
                  label: 'Relationship',
                  icon: Icons.family_restroom_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emergencyContact1PhoneController,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Emergency Contact 2 (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _emergencyContact2NameController,
            label: 'Contact Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _emergencyContact2RelationshipController,
                  label: 'Relationship',
                  icon: Icons.family_restroom_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emergencyContact2PhoneController,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Physical Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (_isLoadingLocation)
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF199A8E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Getting location...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(
                  Icons.my_location,
                  size: 16,
                  color: Color(0xFF199A8E),
                ),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF199A8E),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            gradient: _locationName != null && !_isLoadingLocation
                ? LinearGradient(
                    colors: [
                      const Color(0xFF199A8E).withOpacity(0.1),
                      const Color(0xFF25B5A8).withOpacity(0.05),
                    ],
                  )
                : null,
            color: _locationName == null || _isLoadingLocation ? Colors.white : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _locationName != null && !_isLoadingLocation
                  ? const Color(0xFF199A8E).withOpacity(0.3)
                  : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_locationName != null && !_isLoadingLocation)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF199A8E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locationName!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            if (_locationDetails != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _locationDetails!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: const Color(0xFF199A8E),
                      ),
                    ],
                  ),
                ),
              
              TextFormField(
                controller: _physicalAddressController,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Physical address is required';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: _isLoadingLocation 
                      ? 'Fetching your location...' 
                      : 'Current location will be auto-filled',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: _locationName == null || _isLoadingLocation
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: const Color(0xFF199A8E),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: _locationName != null && !_isLoadingLocation
                        ? const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          )
                        : BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: _locationName != null && !_isLoadingLocation ? 16 : 16,
                    vertical: 16,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3MedicalHistory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Medical History', 'Step 3 of $_totalSteps'),
          const SizedBox(height: 24),
          
          _buildTextField(
            controller: _presentingConditionController,
            label: 'Presenting Condition/Diagnosis',
            icon: Icons.medical_services_outlined,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Presenting condition is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _pastMedicalHistoryController,
            label: 'Past Medical History (Optional)',
            icon: Icons.history_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _allergiesController,
            label: 'Allergies (Optional)',
            icon: Icons.warning_amber_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _currentMedicationsController,
            label: 'Current Medications (Optional)',
            icon: Icons.medication_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _specialNeedsController,
            label: 'Special Needs (Optional)',
            icon: Icons.accessible_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4AssessmentAndVitals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Assessment & Vitals', 'Step 4 of $_totalSteps'),
          const SizedBox(height: 24),
          
          Text(
            'Initial Assessment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildDropdownField(
            label: 'General Condition',
            value: _generalCondition,
            items: const ['stable', 'unstable'],
            onChanged: (value) {
              setState(() {
                _generalCondition = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Hydration',
                  value: _hydrationStatus,
                  items: const ['adequate', 'dehydrated'],
                  onChanged: (value) {
                    setState(() {
                      _hydrationStatus = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Nutrition',
                  value: _nutritionStatus,
                  items: const ['adequate', 'malnourished'],
                  onChanged: (value) {
                    setState(() {
                      _nutritionStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildDropdownField(
            label: 'Mobility',
            value: _mobilityStatus,
            items: const ['independent', 'assisted', 'bedridden'],
            onChanged: (value) {
              setState(() {
                _mobilityStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          
          _buildWoundCheckbox(),
          const SizedBox(height: 16),
          
          if (_hasWounds) ...[
            _buildTextField(
              controller: _woundDescriptionController,
              label: 'Wound Description',
              icon: Icons.note_outlined,
              maxLines: 2,
              validator: (value) {
                if (_hasWounds && (value == null || value.isEmpty)) {
                  return 'Wound description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          
          _buildPainLevelSlider(),
          
          const SizedBox(height: 32),
          
          Text(
            'Vital Signs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _temperatureController,
                  label: 'Temperature (°C)',
                  icon: Icons.thermostat_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final temp = double.tryParse(value);
                    if (temp == null || temp < 30 || temp > 45) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _pulseController,
                  label: 'Pulse (bpm)',
                  icon: Icons.favorite_outline,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final pulse = int.tryParse(value);
                    if (pulse == null || pulse < 30 || pulse > 200) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _respiratoryRateController,
                  label: 'Resp Rate (/min)',
                  icon: Icons.air_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final rate = int.tryParse(value);
                    if (rate == null || rate < 8 || rate > 40) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _bloodPressureController,
                  label: 'BP (mmHg)',
                  icon: Icons.monitor_heart_outlined,
                  hint: '120/80',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (!RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(value)) {
                      return 'Format: 120/80';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _spo2Controller,
                  label: 'SpO₂ (%)',
                  icon: Icons.opacity_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final spo2 = int.tryParse(value);
                    if (spo2 == null || spo2 < 70 || spo2 > 100) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  icon: Icons.scale_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final weight = double.tryParse(value);
                    if (weight == null || weight < 1 || weight > 500) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Nursing Impression',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _nursingImpressionController,
            label: 'Initial Nursing Impression',
            icon: Icons.description_outlined,
            maxLines: 5,
            hint: 'Describe the patient\'s general condition and details of care given...',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nursing impression is required';
              }
              if (value.length < 10) {
                return 'Please provide a detailed impression (min 10 characters)';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWoundCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _hasWounds = !_hasWounds;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasWounds ? const Color(0xFF199A8E) : Colors.grey.shade300,
            width: _hasWounds ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _hasWounds ? const Color(0xFF199A8E) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _hasWounds ? const Color(0xFF199A8E) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: _hasWounds
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Patient has wounds/ulcers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: _hasWounds ? FontWeight.w600 : FontWeight.w500,
                  color: _hasWounds ? const Color(0xFF199A8E) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPainLevelSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pain Level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(Colors.green, Colors.red, _painLevel / 10)!,
                    Color.lerp(Colors.green, Colors.red, _painLevel / 10)!.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_painLevel.toInt()}/10',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Color.lerp(Colors.green, Colors.red, _painLevel / 10),
                  inactiveTrackColor: Colors.grey.shade200,
                  thumbColor: Color.lerp(Colors.green, Colors.red, _painLevel / 10),
                  overlayColor: Color.lerp(Colors.green, Colors.red, _painLevel / 10)!.withOpacity(0.2),
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: _painLevel,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (value) {
                    setState(() {
                      _painLevel = value;
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'No Pain',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Worst Pain',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF199A8E), Color(0xFF25B5A8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_currentStep < _totalSteps - 1) {
                          _nextStep();
                        } else {
                          _submitAssessment();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep < _totalSteps - 1 ? 'Next' : 'Submit Assessment',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep < _totalSteps - 1
                                ? Icons.arrow_forward
                                : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 20,
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

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF199A8E),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF199A8E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              
              if (date != null) {
                controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              }
            },
            validator: (value) {
              if (_isNewPatient && (value == null || value.isEmpty)) {
                return 'Date of birth is required';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'YYYY-MM-DD',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF199A8E),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item[0].toUpperCase() + item.substring(1),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF199A8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}