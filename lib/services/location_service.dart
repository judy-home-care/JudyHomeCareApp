import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // TODO: Replace with your Google Places API Key
  // Get your API key from: https://console.cloud.google.com/
  static const String _apiKey = 'AIzaSyAa6jl4duYHgSa0o3dZh1yUvZ9dUtOAMEU';
  
  final _uuid = const Uuid();
  String? _sessionToken;

  // Generate a new session token
  String _getSessionToken() {
    _sessionToken ??= _uuid.v4();
    return _sessionToken!;
  }

  // Clear session token after place selection
  void clearSessionToken() {
    _sessionToken = null;
  }

  /// Search for places using Google Places Autocomplete API
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    String? countryCode = 'GH', // Ghana by default
    double? latitude,
    double? longitude,
    int radius = 50000, // 50km radius
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final sessionToken = _getSessionToken();
      
      // Build the request URL
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&sessiontoken=$sessionToken'
        '&components=country:${countryCode ?? 'GH'}'
        '${latitude != null && longitude != null ? '&location=$latitude,$longitude&radius=$radius' : ''}'
      );

      debugPrint('🔍 Searching places: $query');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          
          final results = predictions.map((prediction) {
            return PlaceSearchResult.fromJson(prediction);
          }).toList();
          
          debugPrint('✅ Found ${results.length} places');
          return results;
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('⚠️ No results found for: $query');
          return [];
        } else {
          debugPrint('❌ API Error: ${data['status']} - ${data['error_message']}');
          throw Exception('Places API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 Error searching places: $e');
      rethrow;
    }
  }

  /// Get detailed place information by place ID
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final sessionToken = _getSessionToken();
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$_apiKey'
        '&sessiontoken=$sessionToken'
        '&fields=name,formatted_address,geometry,types'
      );

      debugPrint('📍 Fetching place details for: $placeId');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = PlaceDetails.fromJson(data['result']);
          
          // Clear session token after getting details
          clearSessionToken();
          
          debugPrint('✅ Got place details: ${result.name}');
          return result;
        } else {
          debugPrint('❌ Place Details Error: ${data['status']}');
          return null;
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 Error getting place details: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to get address
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$_apiKey'
      );

      debugPrint('🗺️ Reverse geocoding: $latitude, $longitude');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'] as String;
          debugPrint('✅ Got address: $address');
          return address;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('💥 Error reverse geocoding: $e');
      return null;
    }
  }
}

/// Place Search Result Model
class PlaceSearchResult {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  PlaceSearchResult({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] as Map<String, dynamic>?;
    
    return PlaceSearchResult(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String? ?? json['description'] as String,
      secondaryText: structuredFormatting?['secondary_text'] as String? ?? '',
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'place_id': placeId,
    'description': description,
    'main_text': mainText,
    'secondary_text': secondaryText,
    'types': types,
  };
}

/// Place Details Model
class PlaceDetails {
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final List<String> types;

  PlaceDetails({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.types,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    
    return PlaceDetails(
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'formatted_address': formattedAddress,
    'latitude': latitude,
    'longitude': longitude,
    'types': types,
  };
}