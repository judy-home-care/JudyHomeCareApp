import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../services/location_service.dart';
import '../../services/contact_person/contact_person_service.dart';
import '../../models/contact_person/contact_person_models.dart';

class ContactPersonCareRequestScreen extends StatefulWidget {
  final ContactPersonUser contactPerson;
  final LinkedPatient selectedPatient;

  const ContactPersonCareRequestScreen({
    Key? key,
    required this.contactPerson,
    required this.selectedPatient,
  }) : super(key: key);

  @override
  State<ContactPersonCareRequestScreen> createState() =>
      _ContactPersonCareRequestScreenState();
}

class _ContactPersonCareRequestScreenState
    extends State<ContactPersonCareRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _specialRequirementsController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _locationService = LocationService();
  final _contactPersonService = ContactPersonService();

  String? _selectedCareType;
  String? _selectedUrgency = 'routine';
  String? _selectedTime;
  String? _selectedRegion;
  DateTime? _preferredStartDate;
  bool _isLoadingLocation = false;
  bool _isSearchingLocation = false;
  bool _isSubmitting = false;
  Position? _currentPosition;

  List<PlaceSearchResult> _addressSearchResults = [];
  Timer? _debounce;
  bool _showAddressDropdown = false;

  final List<Map<String, String>> careTypes = [
    {'value': 'general_care', 'label': 'General Nursing', 'icon': '🏥'},
    {'value': 'elderly_care', 'label': 'Elderly Care', 'icon': '👵'},
    {'value': 'post_surgical_care', 'label': 'Post-Surgical Care', 'icon': '🏨'},
    {
      'value': 'chronic_disease_management',
      'label': 'Chronic Disease Management',
      'icon': '💊'
    },
    {'value': 'palliative_care', 'label': 'Palliative Care', 'icon': '🕊️'},
    {'value': 'rehabilitation_care', 'label': 'Rehabilitation', 'icon': '🦽'},
    {'value': 'wound_care', 'label': 'Wound Care', 'icon': '🩹'},
    {
      'value': 'medication_management',
      'label': 'Medication Management',
      'icon': '💉'
    },
  ];

  final List<String> urgencyLevels = ['routine', 'urgent', 'emergency'];
  final List<String> timePreferences = [
    'morning',
    'afternoon',
    'evening',
    'night',
    'anytime'
  ];
  final List<String> regions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Northern',
    'Central',
    'Volta'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _descriptionController.dispose();
    _specialRequirementsController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _addressSearchResults.clear();
    super.dispose();
  }

  DateTime get _minStartDate => DateTime.now().add(const Duration(days: 1));

  DateTime get _maxStartDate {
    switch (_selectedUrgency) {
      case 'emergency':
        return DateTime.now().add(const Duration(days: 4));
      case 'urgent':
        return DateTime.now().add(const Duration(days: 7));
      default:
        return DateTime.now().add(const Duration(days: 90));
    }
  }

  String get _dateHintText {
    switch (_selectedUrgency) {
      case 'emergency':
        return 'Select date (within 4 days)';
      case 'urgent':
        return 'Select date (within 7 days)';
      default:
        return 'Preferred start date';
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _onAddressSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (query.trim().isEmpty) {
      setState(() {
        _addressSearchResults.clear();
        _showAddressDropdown = false;
        _isSearchingLocation = false;
      });
      return;
    }

    setState(() {
      _isSearchingLocation = true;
      _showAddressDropdown = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performLocationSearch(query);
      }
    });
  }

  Future<void> _performLocationSearch(String query) async {
    try {
      final results = await _locationService
          .searchPlaces(
        query,
        countryCode: 'GH',
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radius: 50000,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Search took too long');
        },
      );

      if (mounted) {
        setState(() {
          _addressSearchResults = results.take(10).toList();
          _isSearchingLocation = false;
        });

        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'No locations found. Try a different search term.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
          _addressSearchResults.clear();
        });

        String errorMessage = e is TimeoutException
            ? 'Search timeout. Please try again.'
            : 'Error: ${e.toString()}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _onAddressSelected(PlaceSearchResult result) async {
    setState(() {
      _showAddressDropdown = false;
      _isSearchingLocation = true;
    });

    final placeDetails = await _locationService.getPlaceDetails(result.placeId);

    if (!mounted) return;

    if (placeDetails != null) {
      setState(() {
        _addressController.text = placeDetails.name;

        final addressParts = placeDetails.formattedAddress.split(',');
        if (addressParts.length > 1) {
          _cityController.text = addressParts[addressParts.length - 2].trim();
        }

        final matchedRegion = regions.firstWhere(
          (region) => placeDetails.formattedAddress
              .toLowerCase()
              .contains(region.toLowerCase()),
          orElse: () => '',
        );
        if (matchedRegion.isNotEmpty) {
          _selectedRegion = matchedRegion;
        }

        _addressSearchResults.clear();
        _isSearchingLocation = false;
      });

      _dismissKeyboard();
    } else {
      setState(() => _isSearchingLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load location details'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
            'Location services are disabled. Please enable them.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permission denied');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied');
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _currentPosition = position;

      if (mounted) {
        setState(() {
          _addressController.text = 'Current Location';
        });
      }

      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (address != null && address.isNotEmpty) {
        final addressParts = address.split(',');

        setState(() {
          _addressController.text =
              addressParts.isNotEmpty ? addressParts[0].trim() : address;

          if (addressParts.length > 1) {
            final cityIndex =
                addressParts.length >= 3 ? addressParts.length - 2 : 1;
            _cityController.text = addressParts[cityIndex].trim();
          }

          final matchedRegion = regions.firstWhere(
            (region) => address.toLowerCase().contains(region.toLowerCase()),
            orElse: () => '',
          );
          if (matchedRegion.isNotEmpty) {
            _selectedRegion = matchedRegion;
          }

          _isLoadingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Location detected successfully')),
              ],
            ),
            backgroundColor: const Color(0xFF199A8E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _addressController.text = 'Address not found';
          _isLoadingLocation = false;
        });
        _showLocationError(
            'Could not determine your address. Please enter it manually.');
      }
    } catch (e) {
      _showLocationError(
          'Could not get your location. You can enter it manually.');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFFF9A00),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onUrgencyChanged(String? urgency) {
    setState(() {
      _selectedUrgency = urgency;

      if (_preferredStartDate != null) {
        final newMax = _maxStartDate;
        if (_preferredStartDate!.isAfter(newMax)) {
          _preferredStartDate = null;
        }
      }
    });
  }

  Future<void> _submitRequest() async {
    _dismissKeyboard();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCareType == null) {
      _showError('Please select a care type');
      return;
    }

    if (_selectedUrgency == 'urgent' || _selectedUrgency == 'emergency') {
      if (_preferredStartDate == null) {
        _showError(
            'Please select a preferred start date for $_selectedUrgency requests');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      await _contactPersonService.createCareRequest({
        'care_type': _selectedCareType!,
        'urgency_level': _selectedUrgency ?? 'routine',
        'description': _descriptionController.text,
        'special_requirements': _specialRequirementsController.text.isNotEmpty
            ? _specialRequirementsController.text
            : null,
        'service_address': _addressController.text,
        'city': _cityController.text,
        'region': _selectedRegion,
        'preferred_start_date':
            _preferredStartDate?.toIso8601String().split('T')[0],
        'preferred_time': _selectedTime,
      });

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      _showSuccess('Care request submitted successfully!');

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Failed to submit request: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _dismissKeyboard();
        setState(() => _showAddressDropdown = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Home Care',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'For ${widget.selectedPatient.name}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Care Type', Icons.medical_services),
                const SizedBox(height: 12),
                _buildCareTypeSelection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Urgency Level', Icons.warning_amber),
                const SizedBox(height: 12),
                _buildUrgencySelection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Description of Needs', Icons.description),
                const SizedBox(height: 12),
                _buildDescriptionField(),
                const SizedBox(height: 24),
                _buildSectionTitle('Service Location', Icons.location_on),
                const SizedBox(height: 12),
                _buildLocationFields(),
                const SizedBox(height: 24),
                _buildSectionTitle('Scheduling Preferences', Icons.tune),
                const SizedBox(height: 12),
                _buildPreferencesFields(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF199A8E).withOpacity(0.1),
            const Color(0xFF199A8E).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF199A8E).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF199A8E).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline,
                color: Color(0xFF199A8E), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Care for Patient',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are requesting care for ${widget.selectedPatient.name}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF199A8E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }

  Widget _buildCareTypeSelection() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: careTypes.length,
      itemBuilder: (context, index) {
        final type = careTypes[index];
        final isSelected = _selectedCareType == type['value'];

        return GestureDetector(
          onTap: () {
            _dismissKeyboard();
            setState(() => _selectedCareType = type['value']);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF199A8E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF199A8E) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(type['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUrgencySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: urgencyLevels.map((level) {
            final isSelected = _selectedUrgency == level;
            Color color;
            IconData icon;

            switch (level) {
              case 'routine':
                color = const Color(0xFF199A8E);
                icon = Icons.schedule;
                break;
              case 'urgent':
                color = const Color(0xFFFF9A00);
                icon = Icons.warning_amber;
                break;
              case 'emergency':
                color = const Color(0xFFFF4757);
                icon = Icons.emergency;
                break;
              default:
                color = Colors.grey;
                icon = Icons.help;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _dismissKeyboard();
                  _onUrgencyChanged(level);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          color: isSelected ? Colors.white : color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        level[0].toUpperCase() + level.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedUrgency == 'urgent' || _selectedUrgency == 'emergency')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_selectedUrgency == 'emergency'
                        ? const Color(0xFFFF4757)
                        : const Color(0xFFFF9A00))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _selectedUrgency == 'emergency'
                        ? const Color(0xFFFF4757)
                        : const Color(0xFFFF9A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedUrgency == 'emergency'
                          ? 'Emergency requests must start within 4 days'
                          : 'Urgent requests must start within 7 days',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedUrgency == 'emergency'
                            ? const Color(0xFFFF4757)
                            : const Color(0xFFFF9A00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Describe your care needs in detail...',
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF199A8E), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please describe your care needs';
            }
            if (value.length < 20) {
              return 'Please provide at least 20 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _specialRequirementsController,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onEditingComplete: _dismissKeyboard,
          decoration: InputDecoration(
            hintText: 'Any special requirements? (Optional)',
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF199A8E), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        Column(
          children: [
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              onChanged: _onAddressSearchChanged,
              onTap: () {
                if (_addressController.text.isNotEmpty &&
                    _addressSearchResults.isNotEmpty) {
                  setState(() => _showAddressDropdown = true);
                }
              },
              decoration: InputDecoration(
                hintText:
                    _isLoadingLocation ? 'Detecting location...' : 'Street address',
                prefixIcon: _isLoadingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF199A8E)),
                          ),
                        ),
                      )
                    : const Icon(Icons.home, color: Color(0xFF199A8E)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearchingLocation)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF199A8E)),
                          ),
                        ),
                      ),
                    if (_addressController.text.isNotEmpty && !_isSearchingLocation)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        color: Colors.grey,
                        onPressed: () {
                          setState(() {
                            _addressController.clear();
                            _addressSearchResults.clear();
                            _showAddressDropdown = false;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.my_location,
                          color: Color(0xFF199A8E)),
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      tooltip: 'Use current location',
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
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
                  borderSide:
                      const BorderSide(color: Color(0xFF199A8E), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Service address is required';
                }
                return null;
              },
            ),
            if (_showAddressDropdown)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF199A8E).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSearchingLocation
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF199A8E)),
                              ),
                              SizedBox(height: 12),
                              Text('Searching locations...'),
                            ],
                          ),
                        ),
                      )
                    : _addressSearchResults.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('No locations found',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text('Try a different search term',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _addressSearchResults.length,
                            itemBuilder: (context, index) {
                              return _buildAddressSearchResultItem(
                                  _addressSearchResults[index]);
                            },
                          ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.done,
                onEditingComplete: _dismissKeyboard,
                decoration: InputDecoration(
                  hintText: 'City',
                  filled: true,
                  fillColor: Colors.white,
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
                    borderSide:
                        const BorderSide(color: Color(0xFF199A8E), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: InputDecoration(
                  hintText: 'Region',
                  filled: true,
                  fillColor: Colors.white,
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
                    borderSide:
                        const BorderSide(color: Color(0xFF199A8E), width: 2),
                  ),
                ),
                items: regions
                    .map((region) => DropdownMenuItem(
                          value: region,
                          child: Text(region,
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (value) {
                  _dismissKeyboard();
                  setState(() => _selectedRegion = value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddressSearchResultItem(PlaceSearchResult result) {
    IconData icon = Icons.location_on;
    if (result.types.contains('hospital') || result.types.contains('health')) {
      icon = Icons.local_hospital;
    } else if (result.types.contains('point_of_interest')) {
      icon = Icons.place;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onAddressSelected(result),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF199A8E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF199A8E), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.mainText,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A)),
                    ),
                    if (result.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.secondaryText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesFields() {
    final bool isUrgentOrEmergency =
        _selectedUrgency == 'urgent' || _selectedUrgency == 'emergency';

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            _dismissKeyboard();
            final date = await showDatePicker(
              context: context,
              initialDate: _preferredStartDate ?? _minStartDate,
              firstDate: _minStartDate,
              lastDate: _maxStartDate,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF199A8E)),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() => _preferredStartDate = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUrgentOrEmergency && _preferredStartDate == null
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: isUrgentOrEmergency
                      ? (_selectedUrgency == 'emergency'
                          ? const Color(0xFFFF4757)
                          : const Color(0xFFFF9A00))
                      : const Color(0xFF199A8E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _preferredStartDate == null
                            ? _dateHintText
                            : 'Start: ${_preferredStartDate!.day}/${_preferredStartDate!.month}/${_preferredStartDate!.year}',
                        style: TextStyle(
                          color: _preferredStartDate == null
                              ? Colors.grey.shade600
                              : const Color(0xFF1A1A1A),
                          fontSize: 14,
                        ),
                      ),
                      if (isUrgentOrEmergency && _preferredStartDate == null)
                        Text(
                          'Required for $_selectedUrgency requests',
                          style:
                              TextStyle(fontSize: 11, color: Colors.red.shade400),
                        ),
                    ],
                  ),
                ),
                if (_preferredStartDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    color: Colors.grey,
                    onPressed: () => setState(() => _preferredStartDate = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedTime,
          decoration: InputDecoration(
            hintText: 'Preferred time of day (Optional)',
            prefixIcon: const Icon(Icons.access_time, color: Color(0xFF199A8E)),
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF199A8E), width: 2),
            ),
          ),
          items: timePreferences
              .map((time) => DropdownMenuItem(
                  value: time,
                  child: Text(time[0].toUpperCase() + time.substring(1))))
              .toList(),
          onChanged: (value) {
            _dismissKeyboard();
            setState(() => _selectedTime = value);
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF199A8E),
          disabledBackgroundColor: const Color(0xFF199A8E).withOpacity(0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
      ),
    );
  }
}
