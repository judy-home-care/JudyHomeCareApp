import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../services/location_service.dart';
import 'transport_booking_screen.dart';

class TransportLocationSelectionScreen extends StatefulWidget {
  final String transportType;
  final bool isEmergency;
  final int patientId;
  final String patientName;
  
  const TransportLocationSelectionScreen({
    Key? key,
    required this.transportType,
    required this.isEmergency,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  State<TransportLocationSelectionScreen> createState() => _TransportLocationSelectionScreenState();
}

class _TransportLocationSelectionScreenState extends State<TransportLocationSelectionScreen> {
  final _destinationController = TextEditingController();
  final _locationService = LocationService();
  
  Position? _currentPosition;
  String _currentAddress = 'Getting your location...';
  bool _isLoadingLocation = true;
  bool _isSearching = false;
  
  List<PlaceSearchResult> _searchResults = [];
  Timer? _debounce;
  
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    _debounce = null;
    _destinationController.dispose();
    _searchResults.clear();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isDisposed) return;
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!_isDisposed && mounted) {
            setState(() {
              _currentAddress = 'Location permission denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_isDisposed && mounted) {
          setState(() {
            _currentAddress = 'Location permissions are permanently denied';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (_isDisposed) return;
      
      _getAddressAsync(position);
      
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _currentAddress = 'Unable to get location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _getAddressAsync(Position position) async {
    if (_isDisposed) return;
    
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _currentAddress = 'Current Location';
        _isLoadingLocation = false;
      });
    }
    
    try {
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (!_isDisposed && mounted && address != null) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_isDisposed) return;
    
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        _performLocationSearch(query);
      }
    });
  }

  Future<void> _performLocationSearch(String query) async {
    if (_isDisposed) return;
    
    try {
      final results = await _locationService.searchPlaces(
        query,
        countryCode: 'GH',
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radius: 50000,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _searchResults = results.take(10).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching locations: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Error searching locations'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onDestinationSelected(PlaceSearchResult result) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please wait for your location to be detected'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
              const SizedBox(height: 16),
            //   const Text('Loading location details...'),
            ],
          ),
        ),
      ),
    );

    final placeDetails = await _locationService.getPlaceDetails(result.placeId);
    
    if (!mounted || _isDisposed) return;
    
    Navigator.pop(context);

    if (placeDetails != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TransportBookingScreen(
            transportType: widget.transportType,
            isEmergency: widget.isEmergency,
            pickupLocation: _currentAddress,
            pickupPosition: _currentPosition,
            destinationLocation: placeDetails.name,
            destinationAddress: placeDetails.formattedAddress,
            destinationLatitude: placeDetails.latitude,
            destinationLongitude: placeDetails.longitude,
            patientId: widget.patientId,
            patientName: widget.patientName,
            isNurseFlow: false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load location details'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildLocationFields(),
            Expanded(child: _buildContent()),
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
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEmergency ? 'Emergency Transport' : 'Your route',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'For ${widget.patientName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFields() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isLoadingLocation
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentAddress,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _currentAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  color: AppColors.primaryGreen,
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Where to?',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_destinationController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _destinationController.clear();
                        _searchResults.clear();
                      });
                    },
                  ),
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_destinationController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
            const SizedBox(height: 16),
            //const Text('Searching for locations...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _destinationController.text.isNotEmpty) {
      return _buildNoResultsState();
    }

    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Search for your destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Type the hospital, clinic, or address where you need to go',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'No locations found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      cacheExtent: 400,
      itemBuilder: (context, index) {
        return _buildSearchResultItem(_searchResults[index]);
      },
    );
  }

  Widget _buildSearchResultItem(PlaceSearchResult result) {
    IconData icon = Icons.location_on;
    if (result.types.contains('hospital') || result.types.contains('health')) {
      icon = Icons.local_hospital;
    } else if (result.types.contains('point_of_interest')) {
      icon = Icons.place;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDestinationSelected(result),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.mainText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (result.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.secondaryText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}