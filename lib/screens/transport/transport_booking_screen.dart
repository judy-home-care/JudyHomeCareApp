import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/app_colors.dart';
import '../../services/transport/transport_service.dart';
import '../../models/transport/transport_models.dart';

class TransportBookingScreen extends StatefulWidget {
  final String transportType;
  final bool isEmergency;
  final String pickupLocation;
  final Position? pickupPosition;
  final String destinationLocation;
  final String destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final int patientId;
  final String patientName;
  final bool isNurseFlow;
  
  const TransportBookingScreen({
    Key? key,
    required this.transportType,
    required this.isEmergency,
    required this.pickupLocation,
    this.pickupPosition,
    required this.destinationLocation,
    required this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    required this.patientId,
    required this.patientName,
    this.isNurseFlow = true,
  }) : super(key: key);

  @override
  State<TransportBookingScreen> createState() => _TransportBookingScreenState();
}

class _TransportBookingScreenState extends State<TransportBookingScreen> {
  final _transportService = TransportService();
  
  List<Driver> _availableDrivers = [];
  Driver? _selectedDriver;
  bool _isLoadingDrivers = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableDrivers();
  }

  Future<void> _loadAvailableDrivers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingDrivers = true;
    });

    try {
      final result = await _transportService.getAvailableDrivers(
        transportType: widget.transportType,
      );

      if (mounted) {
        if (result['success'] == true) {
          final drivers = result['drivers'] as List<Driver>;
          
          setState(() {
            _availableDrivers = drivers;
            _isLoadingDrivers = false;
            
            if (_availableDrivers.isNotEmpty) {
              _selectedDriver = _availableDrivers[0];
            }
          });
        } else {
          setState(() {
            _isLoadingDrivers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDrivers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEmergency ? 'Emergency Transport' : 'Book Transport',
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildRouteInfoCard(),
          Expanded(
            child: _buildDriversSection(),
          ),
          if (_selectedDriver != null)
            _buildSelectButton(),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isEmergency 
                      ? const Color(0xFFFF4757).withOpacity(0.1)
                      : AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isEmergency ? Icons.emergency : Icons.local_shipping,
                  color: widget.isEmergency 
                      ? const Color(0xFFFF4757) 
                      : AppColors.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEmergency ? 'Emergency Transport' : 'Medical Transport',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Select your driver',
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
          
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 20),
          
          _buildLocationRow(
            icon: Icons.my_location,
            label: 'Pickup Location',
            location: widget.pickupLocation,
            color: AppColors.primaryGreen,
          ),
          
          const SizedBox(height: 16),
          
          _buildLocationRow(
            icon: Icons.location_on,
            label: 'Destination',
            location: widget.destinationLocation,
            color: const Color(0xFFFF4757),
          ),
          
          if (widget.destinationAddress.isNotEmpty && 
              widget.destinationAddress != widget.destinationLocation) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                widget.destinationAddress,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String location,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriversSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'Available Drivers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isLoadingDrivers)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_availableDrivers.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoadingDrivers
                ? _buildLoadingState()
                : _availableDrivers.isEmpty
                    ? _buildNoDriversState()
                    : _buildDriversList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading available drivers...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDriversState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Drivers Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no drivers available for ${widget.transportType} transport at the moment. Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAvailableDrivers,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _availableDrivers.length,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        return _buildDriverCard(_availableDrivers[index]);
      },
    );
  }

  Widget _buildDriverCard(Driver driver) {
    final isSelected = _selectedDriver?.id == driver.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDriver = driver;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryGreen 
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primaryGreen.withOpacity(0.15)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: isSelected ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.primaryGreen.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primaryGreen,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name ?? 'Driver',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (driver.vehicleModel != null)
                        Text(
                          driver.vehicleModel!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              driver.vehicleNumber ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (driver.vehicleColor != null) ...[
                            const SizedBox(width: 8), // Reduced from 12
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getColorFromString(driver.vehicleColor!),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                driver.vehicleColor!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      )
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Column(
                  children: [
                    if (driver.averageRating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB648).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFB648),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              driver.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isSelected) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'silver':
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSelectButton() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedDriver != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Selected: ${_selectedDriver!.name ?? "Driver"} - ${_selectedDriver!.vehicleNumber ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedDriver == null ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Future<void> _confirmBooking() async {
    if (_selectedDriver == null) return;
    
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
              //const Text('Creating booking...'),
            ],
          ),
        ),
      ),
    );

    try {
      final createRequest = CreateTransportRequest(
        patientId: widget.patientId,
        driverId: _selectedDriver!.id,
        transportType: widget.transportType,
        priority: widget.isEmergency ? 'emergency' : 'routine',
        pickupLocation: widget.pickupLocation,
        pickupAddress: widget.pickupLocation,
        pickupLatitude: widget.pickupPosition?.latitude,
        pickupLongitude: widget.pickupPosition?.longitude,
        destinationLocation: widget.destinationLocation,
        destinationAddress: widget.destinationAddress,
        destinationLatitude: widget.destinationLatitude,
        destinationLongitude: widget.destinationLongitude,
        scheduledTime: null,
        reason: widget.isEmergency 
            ? 'Emergency medical transport required' 
            : 'Scheduled patient transport to medical facility',
        notes: widget.isEmergency ? 'Emergency transport request' : null,
      );

      final result = await _transportService.createTransportRequest(createRequest);

      if (!mounted) return;

      Navigator.pop(context);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Booking confirmed with ${_selectedDriver!.name ?? "driver"}',
                  ),
                ),
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

        // FIXED: Navigate back to TransportRequestScreen by popping until we reach it
        // This will pop: TransportBookingScreen -> TransportLocationSelectionScreen -> TransportPatientSelectionScreen
        await Future.delayed(const Duration(milliseconds: 500));
        
      if (mounted) {
        if (widget.isNurseFlow) {
          // Nurse flow: Pop 3 times
          // TransportBookingScreen -> TransportLocationSelectionScreen -> TransportPatientSelectionScreen -> TransportRequestScreen
          Navigator.of(context).pop(true);
          Navigator.of(context).pop(true);
          Navigator.of(context).pop(true);
        } else {
          // Patient flow: Pop 2 times
          // TransportBookingScreen -> TransportLocationSelectionScreen -> TransportRequestScreen
          Navigator.of(context).pop(true);
          Navigator.of(context).pop(true);
        }
      }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Failed to create booking',
                  ),
                ),
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
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('An error occurred while creating the booking'),
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