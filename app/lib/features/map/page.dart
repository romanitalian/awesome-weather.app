
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  final double lat;
  final double lon;
  final List<LatLng> favorites;
  const MapPage({super.key, required this.lat, required this.lon, required this.favorites});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? selected;
  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.lat, widget.lon);
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 10, onTap: (tapPosition, latlng){ setState(()=>selected=latlng); }),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'app.awesome.weather'),
          MarkerLayer(markers: [
            Marker(point: center, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red)),
            ...widget.favorites.map((p)=>Marker(point: p, width: 24, height: 24, child: const Icon(Icons.star, color: Colors.amber))).toList(),
            if (selected != null) Marker(point: selected!, width: 36, height: 36, child: const Icon(Icons.my_location, color: Colors.blue)),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selected==null ? null : (){ Navigator.of(context).pop(selected); },
        icon: const Icon(Icons.check), label: const Text('Select'),
      ),
    );
  }
}
