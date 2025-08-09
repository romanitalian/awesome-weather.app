import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app/shared/location_service.dart';
import 'package:app/features/geocode/models.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  final Place? initialLocation;
  final Function(Place) onLocationSelected;

  const MapScreen({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoading = false;
  String? _selectedAddress;
  double _zoom = 10.0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    // Set initial location
    if (widget.initialLocation != null) {
      _selectedLocation = LatLng(
        widget.initialLocation!.lat,
        widget.initialLocation!.lon,
      );
      _selectedAddress = widget.initialLocation!.name;
    }

    // Get current location
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          if (_selectedLocation == null) {
            _selectedLocation = _currentLocation;
            _zoom = 15.0;
          }
        });
        
        // Get address for current location
        if (_selectedAddress == null) {
          final address = await _locationService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
          setState(() => _selectedAddress = address ?? 'Unknown location');
        }
      }
    } catch (e) {
      print('Error getting current location: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = newLocation;
          _selectedLocation = newLocation;
          _zoom = 15.0;
        });

        // Update map
        _mapController.move(newLocation, _zoom);

        // Get address
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        setState(() => _selectedAddress = address ?? 'Current location');
      }
    } catch (e) {
      _showErrorDialog('location.error'.tr(), e.toString());
    }

    setState(() => _isLoading = false);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isLoading = true;
    });

    try {
      final address = await _locationService.getAddressFromCoordinates(
        point.latitude,
        point.longitude,
      );
      setState(() {
        _selectedAddress = address ?? 'Selected location';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedAddress = 'Selected location';
        _isLoading = false;
      });
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      final place = Place(
        name: _selectedAddress ?? 'Selected location',
        country: '',
        lat: _selectedLocation!.latitude,
        lon: _selectedLocation!.longitude,
      );
      widget.onLocationSelected(place);
      Navigator.of(context).pop();
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('app.ok'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _selectedLocation == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('map.title'.tr()),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('map.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'map.current_location'.tr(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? const LatLng(59.93, 30.31),
              initialZoom: _zoom,
              onTap: _onMapTap,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'map.selected_location'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedAddress ?? 'Unknown location',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirmLocation,
                              child: Text('map.confirm_location'.tr()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('app.cancel'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Positioned(
              top: 100,
              right: 20,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
