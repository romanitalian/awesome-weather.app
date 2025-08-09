import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/features/geocode/models.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
    double desiredAccuracy = LocationAccuracy.high,
  }) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeout,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> getLastKnownPosition() async {
    try { return await Geolocator.getLastKnownPosition(); } catch (_) { return null; }
  }

  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.locality?.isNotEmpty == true) parts.add(p.locality!);
        if (p.administrativeArea?.isNotEmpty == true) parts.add(p.administrativeArea!);
        if (p.country?.isNotEmpty == true) parts.add(p.country!);
        return parts.join(', ');
      }
      return null;
    } catch (_) { return null; }
  }

  Future<List<Place>> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      return locations.map((l) => Place(name: address, country: '', lat: l.latitude, lon: l.longitude)).toList();
    } catch (_) { return []; }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}


