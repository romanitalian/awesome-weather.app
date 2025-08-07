
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/shared/api.dart';
import 'package:app/shared/favorites.dart';
import 'package:app/features/marine/service.dart';
import 'package:app/features/marine/models.dart';
import 'package:app/features/map/page.dart';
import 'package:latlong2/latlong.dart';
import 'service.dart';
import 'package:app/features/geocode/service.dart';
import 'package:app/features/geocode/models.dart';
import 'models.dart';

class WeatherScreen extends StatefulWidget {
  final String apiBaseUrl;
  const WeatherScreen({super.key, required this.apiBaseUrl});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<Place> _suggestions = const [];
  WeatherRS? rs;
  MarineRS? marine;
  bool loading = true;
  String? error;
  String units = 'metric';
  double? lastLat;
  double? lastLon;
  String? lastName;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  final FavoritesStore _fav = FavoritesStore();
  List<Place> _favorites = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedOrDefault();
  }

  Future<void> _load() async {
    _suggestions = const [];
    try {
      final api = ApiClient(widget.apiBaseUrl);
      final svc = WeatherService(api);
      final v = await svc.fetch(lat: (lastLat ?? 59.93), lon: (lastLon ?? 30.31), units: units);
      setState(() { rs = v; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _loadSavedOrDefault() async {
    setState(() { loading = true; });
    final prefs = await SharedPreferences.getInstance();
    units = prefs.getString('units') ?? 'metric';
    _favorites = await _fav.load();
    final lat = prefs.getDouble('last_lat');
    final lon = prefs.getDouble('last_lon');
    final name = prefs.getString('last_name');
    if (lat != null && lon != null) {
      lastLat = lat; lastLon = lon; lastName = name;
      await _loadFor(lat, lon, save: false);
    } else {
      await _load();
    }
  }

  void _switchUnits(String u) {
    if (units == u) return;
    setState(() { units = u; loading = true; });
    _persistUnits(u);
    _load();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    final api = ApiClient(widget.apiBaseUrl);
    final geo = GeocodeService(api);
    final res = await geo.search(q);
    setState(() { _suggestions = res.results; });
  }

  void _selectPlace(Place p) {
    setState(() { loading = true; });
    _loadFor(p.lat, p.lon, name: p.name);
  }

  Future<void> _loadFor(double lat, double lon, {String? name, bool save = true}) async {
    try {
      final api = ApiClient(widget.apiBaseUrl);
      final svc = WeatherService(api);
      final v = await svc.fetch(lat: lat, lon: lon, units: units);
      MarineRS? m;
      try { m = await MarineService(api).fetch(lat: lat, lon: lon); } catch (_) {}
      setState(() { rs = v; marine = m; loading = false; error = null; lastLat = lat; lastLon = lon; lastName = name ?? lastName; });
      if (save) { _persistLocation(lat, lon, lastName); }
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _openMap() async {
    final fav = _favorites.map((p) => LatLng(p.lat, p.lon)).toList();
    final currentLat = lastLat ?? 59.93;
    final currentLon = lastLon ?? 30.31;
    final LatLng? sel = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapPage(lat: currentLat, lon: currentLon, favorites: fav)),
    );
    if (sel != null) {
      setState(() { loading = true; });
      await _loadFor(sel.latitude, sel.longitude);
    }
  }

  Future<void> _persistLocation(double lat, double lon, String? name) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('last_lat', lat);
    await p.setDouble('last_lon', lon);
    if (name != null && name.isNotEmpty) {
      await p.setString('last_name', name);
    }
  }

  Future<void> _persistUnits(String u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('units', u);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Text('Error: $error')));
    final d = rs!.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Awesome Weather')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ElevatedButton.icon(onPressed: _openMap, icon: const Icon(Icons.map), label: const Text('Map')),
              const SizedBox(width: 12),
              if (lastName != null) Text('Location: $lastName')
            ],
          ),
          const SizedBox(height: 8),
          if (_favorites.isNotEmpty) ...[
            const Text('Favorites:'),
            ...List.generate(_favorites.length, (i){ final p=_favorites[i]; return ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(p.name), subtitle: Text(p.country),
              onTap: ()=>_selectPlace(p),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async { final items = await _fav.removeAt(i); setState(()=>_favorites = items); }),
            );}),
            const Divider(),
          ],
          TextField(
            decoration: const InputDecoration(labelText: 'Search location'),
            controller: _searchCtrl,
            onChanged: (val) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _search(val));
            },
          ),
          const SizedBox(height: 8),
          if (_suggestions.isNotEmpty) ...[
            const Text('Results:'),
            ..._suggestions.take(5).map((e)=>ListTile(title: Text(e.name), subtitle: Text(e.country), onTap: ()=>_selectPlace(e), trailing: IconButton(icon: const Icon(Icons.star_border), onPressed: () async { final items = await _fav.add(e); setState(()=>_favorites = items); },))).toList(),
            const Divider(),
          ],
          Row(children:[
            const Text('Units:'), const SizedBox(width: 8),
            ElevatedButton(onPressed: ()=>_switchUnits('metric'), child: const Text('Metric')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: ()=>_switchUnits('imperial'), child: const Text('Imperial')),
          ]),
          Text('Lat: ${d.latitude}, Lon: ${d.longitude}'),
          Text('Current: ${d.current.temperature}${d.units.temperature}, wind ${d.current.windSpeed}${d.units.windSpeed}'),
          const SizedBox(height: 12),
          const Text('Hourly (first 12):'),
          const SizedBox(height: 8),
          ...d.hourly.take(12).map((h)=>Text('${h.time}  T=${h.temperature}${d.units.temperature}  W=${h.windSpeed}${d.units.windSpeed}  P=${h.pressure}${d.units.pressure}')).toList(),
          const SizedBox(height: 12),
          const Text('Daily:'),
          const SizedBox(height: 8),
          ...d.daily.map((day)=>Text('${day.date}: ${day.tempMin}..${day.tempMax}${d.units.temperature}, precip ${day.precipitationSum}${d.units.precipitation}')).toList(),
          const SizedBox(height: 12),
          if (marine != null) ...[
            const Text('Marine (12h):'),
            const SizedBox(height: 8),
            ...marine!.data.hourly.take(12).map((h)=>Text('${h.time}  H=${h.waveHeight}${marine!.data.units.waveHeight}  P=${h.wavePeriod}${marine!.data.units.wavePeriod}  Dir=${h.waveDirection}${marine!.data.units.waveDirection}')).toList(),
          ],
        ],
      ),
    );
  }
}

