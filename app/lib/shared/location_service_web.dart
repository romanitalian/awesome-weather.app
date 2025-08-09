import 'package:app/features/geocode/models.dart';

class Position {
  final double latitude;
  final double longitude;
  Position({required this.latitude, required this.longitude});
}

enum LocationAccuracy { lowest, low, medium, high, best, bestForNavigation }

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> isLocationServiceEnabled() async => false;
  Future<dynamic> checkPermission() async => null;
  Future<dynamic> requestPermission() async => null;

  Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
    double desiredAccuracy = 0,
  }) async {
    // Geolocation via browser JS API could be added; return null for now
    return null;
  }

  Future<Position?> getLastKnownPosition() async => null;

  Future<String?> getAddressFromCoordinates(double lat, double lon) async => null;

  Future<List<Place>> getCoordinatesFromAddress(String address) async => [];

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) => 0;
}


