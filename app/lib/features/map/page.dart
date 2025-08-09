
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
  bool showRadar = false;
  int radarOffset = 0; // 0 = latest, up to ~12
  double radarOpacity = 0.6;
  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.lat, widget.lon);
    return Scaffold(
      appBar: AppBar(title: const Text('Map'), actions:[
        Row(children:[
          const Text('Radar'), Switch(value: showRadar, onChanged: (v)=>setState(()=>showRadar=v)),
        ])
      ]),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 10, onTap: (tapPosition, latlng){ setState(()=>selected=latlng); }),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'app.awesome.weather'),
          if (showRadar)
            TileLayer(
              urlTemplate: 'https://tilecache.rainviewer.com/v2/radar/nowcast_${radarOffset}/256/{z}/{x}/{y}/2/1_1.png',
              userAgentPackageName: 'app.awesome.weather',
              tileProvider: NetworkTileProvider(),
              tileBuilder: (ctx, child, tile) => Opacity(opacity: radarOpacity, child: child),
            ),
          MarkerLayer(markers: [
            Marker(point: center, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red)),
            ...widget.favorites.map((p)=>Marker(point: p, width: 24, height: 24, child: const Icon(Icons.star, color: Colors.amber))).toList(),
            if (selected != null) Marker(point: selected!, width: 36, height: 36, child: const Icon(Icons.my_location, color: Colors.blue)),
          ]),
        ],
      ),
      bottomNavigationBar: showRadar ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children:[
          Row(children:[
            const Text('← older'),
            Expanded(child: Slider(min: 0, max: 12, divisions: 12, value: radarOffset.toDouble(), label: 'T-${radarOffset*10}m', onChanged: (v){ setState(()=>radarOffset=v.toInt()); })),
            const Text('now →'),
          ]),
          Row(children:[
            const Text('Opacity'),
            Expanded(child: Slider(min: 0.1, max: 1.0, divisions: 9, value: radarOpacity, label: radarOpacity.toStringAsFixed(1), onChanged: (v){ setState(()=>radarOpacity=v); })),
          ]),
        ]),
      ) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selected==null ? null : (){ Navigator.of(context).pop(selected); },
        icon: const Icon(Icons.check), label: const Text('Select'),
      ),
    );
  }
}
