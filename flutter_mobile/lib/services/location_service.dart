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

  /// Reverse geocode latitude and longitude using backend API or OpenStreetMap Nominatim API directly.
  Future<String> reverseGeocode(double latitude, double longitude) async {
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
        final addr = data['address']?.toString();
        if (addr != null && addr.isNotEmpty && addr != 'Address not resolved') {
          return addr;
        }
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
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
        },
      );
      if (res.statusCode == 200 && res.data is Map) {
        final displayName = res.data['display_name']?.toString();
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {}

    return 'Location unavailable';
  }

}
