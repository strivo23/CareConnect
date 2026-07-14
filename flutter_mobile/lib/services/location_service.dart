import 'package:geolocator/geolocator.dart';
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

  /// Call our backend reverse-geocoding API to resolve coordinates to address.
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
        return data['address']?.toString() ?? 'Address not resolved';
      }
    } catch (_) {}
    return 'Address not resolved';
  }
}
