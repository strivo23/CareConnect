import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../core/services/api_client.dart';


class LocationService {
  LocationService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Request runtime location permission and get current position.
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Reverse geocode latitude and longitude returning structured details.
  Future<Map<String, String>> reverseGeocodeDetails(double latitude, double longitude) async {
    final fallback = {
      'address': 'Location unavailable',
      'city': '',
      'state': '',
      'country': '',
      'pincode': '',
    };

    try {
      final response = await _client.get(
        '/api/geocode/reverse/',
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final addr = data['address']?.toString() ?? 'Location unavailable';
        return {
          'address': addr,
          'city': data['city']?.toString() ?? '',
          'state': data['state']?.toString() ?? '',
          'country': data['country']?.toString() ?? '',
          'pincode': data['pincode']?.toString() ?? '',
        };
      }
    } catch (_) {}

    // Fallback: Query OpenStreetMap Nominatim API directly
    try {
      final dio = Dio(BaseOptions(
        headers: {'User-Agent': 'CareConnect-MobileApp/1.0 (emergency-response)'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude,
          'lon': longitude,
        },
      );
      if (res.statusCode == 200 && res.data is Map) {
        final rawAddr = res.data['address'] as Map?;
        final displayName = res.data['display_name']?.toString() ?? 'Location unavailable';
        if (rawAddr != null) {
          return {
            'address': displayName,
            'city': rawAddr['city']?.toString() ?? rawAddr['town']?.toString() ?? rawAddr['village']?.toString() ?? '',
            'state': rawAddr['state']?.toString() ?? '',
            'country': rawAddr['country']?.toString() ?? '',
            'pincode': rawAddr['postcode']?.toString() ?? '',
          };
        }
        return {'address': displayName, 'city': '', 'state': '', 'country': '', 'pincode': ''};
      }
    } catch (_) {}

    return fallback;
  }

  /// Reverse geocode latitude and longitude returning formatted address.
  Future<String> reverseGeocode(double latitude, double longitude) async {
    final details = await reverseGeocodeDetails(latitude, longitude);
    return details['address'] ?? 'Location unavailable';
  }
}
