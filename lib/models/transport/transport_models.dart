double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

// Transport Request Model
class TransportRequest {
  final int id;
  final int patientId;
  final String patientName;
  final int? driverId;
  final Driver? driver;
  final String transportType;
  final String priority;
  final String status;
  final String pickupLocation;
  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String destinationLocation;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final String? reason;
  final String? specialRequirements;
  final String? contactPerson;
  final double? estimatedCost;
  final double? actualCost;
  final int? rating;
  final String? feedback;
  final String? scheduledAt;
  final String? completedAt;
  final String? cancelledAt;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  TransportRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.driverId,
    this.driver,
    required this.transportType,
    required this.priority,
    required this.status,
    required this.pickupLocation,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.destinationLocation,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.reason,
    this.specialRequirements,
    this.contactPerson,
    this.estimatedCost,
    this.actualCost,
    this.rating,
    this.feedback,
    this.scheduledAt,
    this.completedAt,
    this.cancelledAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

factory TransportRequest.fromJson(Map<String, dynamic> json) {
  return TransportRequest(
    id: json['id'] as int,
    patientId: json['patient_id'] as int,
    patientName: json['patient_name'] as String? ?? 'Unknown Patient',
    driverId: json['driver_id'] as int?,
    driver: json['driver'] != null 
        ? Driver.fromJson(json['driver'] as Map<String, dynamic>)
        : null,
    transportType: json['transport_type'] as String? ?? 'regular', // ✅ Safe with default
    priority: json['priority'] as String? ?? 'medium',             // ✅ Safe with default
    status: json['status'] as String? ?? 'requested',              // ✅ Safe with default
    pickupLocation: json['pickup_location'] as String? ?? '',      // ✅ Safe with default
    pickupAddress: json['pickup_address'] as String?,
    pickupLatitude: json['pickup_latitude'] != null 
        ? _parseDouble(json['pickup_latitude'])
        : null,
    pickupLongitude: json['pickup_longitude'] != null 
        ? _parseDouble(json['pickup_longitude'])
        : null,
    destinationLocation: json['destination_location'] as String? ?? '', // ✅ Safe with default
    destinationAddress: json['destination_address'] as String?,
    destinationLatitude: json['destination_latitude'] != null 
        ? _parseDouble(json['destination_latitude'])
        : null,
    destinationLongitude: json['destination_longitude'] != null 
        ? _parseDouble(json['destination_longitude'])
        : null,
    distanceKm: json['distance_km'] != null 
        ? _parseDouble(json['distance_km'])
        : null,
    estimatedDurationMinutes: json['estimated_duration_minutes'] != null 
        ? _parseInt(json['estimated_duration_minutes'])
        : null,
    reason: json['reason'] as String?,
    specialRequirements: json['special_requirements'] as String?,
    contactPerson: json['contact_person'] as String?,
    estimatedCost: json['estimated_cost'] != null 
        ? _parseDouble(json['estimated_cost'])
        : null,
    actualCost: json['actual_cost'] != null 
        ? _parseDouble(json['actual_cost'])
        : null,
    rating: json['rating'] != null 
        ? _parseInt(json['rating'])
        : null,
    feedback: json['feedback'] as String?,
    scheduledAt: json['scheduled_at'] as String?,
    completedAt: json['completed_at'] as String?,
    cancelledAt: json['cancelled_at'] as String?,
    notes: json['notes'] as String?,
    createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(), // ✅ Safe with default
    updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(), // ✅ Safe with default
  );
}

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'patient_name': patientName,
    'driver_id': driverId,
    'driver': driver?.toJson(),
    'transport_type': transportType,
    'priority': priority,
    'status': status,
    'pickup_location': pickupLocation,
    'pickup_address': pickupAddress,
    'pickup_latitude': pickupLatitude,
    'pickup_longitude': pickupLongitude,
    'destination_location': destinationLocation,
    'destination_address': destinationAddress,
    'destination_latitude': destinationLatitude,
    'destination_longitude': destinationLongitude,
    'distance_km': distanceKm,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'reason': reason,
    'special_requirements': specialRequirements,
    'contact_person': contactPerson,
    'estimated_cost': estimatedCost,
    'actual_cost': actualCost,
    'rating': rating,
    'feedback': feedback,
    'scheduled_at': scheduledAt,
    'completed_at': completedAt,
    'cancelled_at': cancelledAt,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  String get statusLabel {
    switch (status) {
      case 'requested':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get typeLabel {
    switch (transportType) {
      case 'ambulance':
        return 'Ambulance';
      case 'regular':
        return 'Medical Transport';
      default:
        return transportType;
    }
  }

  String get priorityLabel {
    switch (priority.toLowerCase()) {
      case 'emergency':
        return 'Emergency';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  DateTime? get scheduledTime {
    if (scheduledAt == null) return null;
    try {
      return DateTime.parse(scheduledAt!);
    } catch (e) {
      return null;
    }
  }

  DateTime? get completedTime {
    if (completedAt == null) return null;
    try {
      return DateTime.parse(completedAt!);
    } catch (e) {
      return null;
    }
  }

  DateTime? get cancelledTime {
    if (cancelledAt == null) return null;
    try {
      return DateTime.parse(cancelledAt!);
    } catch (e) {
      return null;
    }
  }
}

// Create Transport Request Model
class CreateTransportRequest {
  final int patientId;
  final int driverId;
  final String transportType;
  final String priority;
  final String pickupLocation;
  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String destinationLocation;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? scheduledTime;
  final String? reason;
  final String? specialRequirements;
  final String? contactPerson;
  final String? notes;

  CreateTransportRequest({
    required this.patientId,
    required this.driverId,
    required this.transportType,
    required this.priority,
    required this.pickupLocation,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.destinationLocation,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.scheduledTime,
    this.reason,
    this.specialRequirements,
    this.contactPerson,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'patient_id': patientId,
      'driver_id': driverId,
      'transport_type': transportType,
      'priority': priority,
      'pickup_location': pickupLocation,
      'pickup_address': pickupAddress ?? pickupLocation,
      'destination_location': destinationLocation,
      'scheduled_time': scheduledTime,
      'reason': reason ?? notes ?? 'Medical transport',
    };

    if (pickupLatitude != null) json['pickup_latitude'] = pickupLatitude;
    if (pickupLongitude != null) json['pickup_longitude'] = pickupLongitude;
    if (destinationAddress != null) json['destination_address'] = destinationAddress;
    if (destinationLatitude != null) json['destination_latitude'] = destinationLatitude;
    if (destinationLongitude != null) json['destination_longitude'] = destinationLongitude;
    if (specialRequirements != null) json['special_requirements'] = specialRequirements;
    if (contactPerson != null) json['contact_person'] = contactPerson;
    if (notes != null) json['notes'] = notes;

    return json;
  }
}

// Driver Model
class Driver {
  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String? vehicleType;
  final String? vehicleModel;
  final String? vehicleNumber;
  final String? vehicleColor;
  final String? licenseNumber;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? averageRating;
  final int? totalTrips;
  final String? createdAt;
  final String? updatedAt;

  Driver({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.vehicleType,
    this.vehicleModel,
    this.vehicleNumber,
    this.vehicleColor,
    this.licenseNumber,
    required this.isAvailable,
    this.currentLatitude,
    this.currentLongitude,
    this.averageRating,
    this.totalTrips,
    this.createdAt,
    this.updatedAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      licenseNumber: json['license_number'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      currentLatitude: json['current_latitude'] != null 
          ? _parseDouble(json['current_latitude'])
          : null,
      currentLongitude: json['current_longitude'] != null 
          ? _parseDouble(json['current_longitude'])
          : null,
      averageRating: json['average_rating'] != null 
          ? _parseDouble(json['average_rating']) 
          : null,
      totalTrips: json['total_trips'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'vehicle_type': vehicleType,
    'vehicle_model': vehicleModel,
    'vehicle_number': vehicleNumber,
    'vehicle_color': vehicleColor,
    'license_number': licenseNumber,
    'is_available': isAvailable,
    'current_latitude': currentLatitude,
    'current_longitude': currentLongitude,
    'average_rating': averageRating,
    'total_trips': totalTrips,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}