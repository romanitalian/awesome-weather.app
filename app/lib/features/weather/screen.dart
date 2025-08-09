
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app/shared/api.dart';
import 'package:app/shared/favorites.dart';
import 'package:app/shared/settings.dart';
import 'package:app/shared/location_service.dart';
import 'package:app/features/marine/service.dart';
import 'package:app/features/marine/models.dart';
import 'service.dart';
import 'package:app/features/geocode/service.dart';
import 'package:app/features/geocode/models.dart';
import 'models.dart';
import 'package:app/features/alerts/service.dart';
import 'package:app/features/alerts/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:app/features/favorites/page.dart';
import 'package:app/features/settings/screen.dart';
import 'package:app/features/map/screen.dart';
import 'package:intl/intl.dart';

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
  AlertsRS? alerts;
  bool loading = true;
  String? error;
  bool online = true;
  String xCache = '';
  String units = SettingsService.unitsMetric;
  double alertWind = 10.0;
  double alertPrecip = 1.0;
  double? lastLat;
  double? lastLon;
  String? lastName;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  final FavoritesStore _fav = FavoritesStore();
  final SettingsService _settings = SettingsService();
  final LocationService _locationService = LocationService();
  List<Place> _favorites = const [];

  // Date formatters
  late DateFormat _timeFormat;
  late DateFormat _fullDateFormat;

  @override
  void initState() {
    super.initState();
    _initializeFormatters();
    _loadSavedOrDefault();
  }

  void _initializeFormatters() {
    final locale = context.locale.languageCode;
    _timeFormat = DateFormat('HH:mm', locale);
    _fullDateFormat = DateFormat('MMM dd, yyyy', locale);
  }

  Future<void> _load() async {
    _suggestions = const [];
    try {
      // Add delay to ensure backend is ready
      await Future.delayed(const Duration(seconds: 2));

      final api = ApiClient(widget.apiBaseUrl);
      final svc = WeatherService(api);
      final v = await svc.fetch(lat: (lastLat ?? _settings.defaultLatitude), lon: (lastLon ?? _settings.defaultLongitude), units: units);
      final prefs = await SharedPreferences.getInstance();
      xCache = prefs.getString('last_weather_x_cache') ?? '';
      setState(() { rs = v; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _loadSavedOrDefault() async {
    setState(() { loading = true; });
    await _settings.init();
    
    units = _settings.units;
    alertWind = _settings.alertWindThreshold;
    alertPrecip = _settings.alertPrecipThreshold;
    _favorites = await _fav.load();
    
    final lat = _settings.defaultLatitude;
    final lon = _settings.defaultLongitude;
    final name = _settings.defaultLocationName;
    
    lastLat = lat; 
    lastLon = lon; 
    lastName = name;
    await _loadFor(lat, lon, save: false);
    
    // connectivity
    Connectivity().onConnectivityChanged.listen((res){
      final nowOnline = res.isNotEmpty && !res.contains(ConnectivityResult.none);
      if (nowOnline != online) { setState(()=>online = nowOnline); }
    });
  }

  void _switchUnits(String u) {
    if (units == u) return;
    setState(() { units = u; loading = true; });
    _settings.setUnits(u);
    _load();
  }

  Future<void> _persistThresholds() async {
    await _settings.setAlertThresholds(alertWind, alertPrecip);
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    try {
      final api = ApiClient(widget.apiBaseUrl);
      final svc = GeocodeService(api);
      final results = await svc.search(query);
      setState(() => _suggestions = results.results);
    } catch (e) {
      // ignore search errors
    }
  }

  Future<void> _selectPlace(Place p) async {
    setState(() { loading = true; });
    await _loadFor(p.lat, p.lon, name: p.name);
  }

  Future<void> _loadFor(double lat, double lon, {String? name, bool save = true}) async {
    try {
      final api = ApiClient(widget.apiBaseUrl);
      final weatherSvc = WeatherService(api);
      final marineSvc = MarineService(api);
      final alertsSvc = AlertsService(api);

      final weather = await weatherSvc.fetch(lat: lat, lon: lon, units: units);
      final marineData = await marineSvc.fetch(lat: lat, lon: lon);
      final alertsData = await alertsSvc.fetch(lat: lat, lon: lon, units: units, windSpeedGte: alertWind, precipGte: alertPrecip);

      if (save) {
        await _settings.setDefaultLocation(lat, lon, name ?? _settings.defaultLocationName);
      }

      setState(() {
        rs = weather;
        marine = marineData;
        alerts = alertsData;
        lastLat = lat;
        lastLon = lon;
        if (name != null) lastName = name;
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() { loading = true; });
    
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        await _loadFor(
          position.latitude,
          position.longitude,
          name: address ?? 'location.current_location'.tr(),
          save: true,
        );
      } else {
        setState(() { loading = false; });
        _showErrorDialog('location.error'.tr(), 'errors.location_error'.tr());
      }
    } catch (e) {
      setState(() { loading = false; });
      _showErrorDialog('location.error'.tr(), e.toString());
    }
  }

  void _openMap() async {
    Place? currentPlace;
    if (lastLat != null && lastLon != null) {
      currentPlace = Place(
        name: lastName ?? 'location.current_location'.tr(),
        country: '',
        lat: lastLat!,
        lon: lastLon!,
      );
    }

    final selectedPlace = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: currentPlace,
          onLocationSelected: (place) => place,
        ),
      ),
    );

    if (selectedPlace != null) {
      await _loadFor(selectedPlace.lat, selectedPlace.lon, name: selectedPlace.name);
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
    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('app.loading'.tr()),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('${'app.error'.tr()}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { loading = true; error = null; });
                  _load();
                },
                child: Text('app.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    if (rs == null) {
      return Scaffold(
        body: Center(child: Text('errors.weather_error'.tr())),
      );
    }

    final d = rs!.data;

    return Scaffold(
      appBar: AppBar(
        title: Text('app.title'.tr()),
        actions: [
          IconButton(
            icon: Icon(online ? Icons.wifi : Icons.wifi_off),
            onPressed: null,
            tooltip: online ? 'status.online'.tr() : 'status.offline'.tr(),
          ),
          if (xCache.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cached),
              onPressed: null,
              tooltip: '${'status.cached'.tr()}: $xCache',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'location.current_location'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _openMap,
            tooltip: 'app.map'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${'location.latitude'.tr()}: ${d.latitude.toStringAsFixed(4)}, ${'location.longitude'.tr()}: ${d.longitude.toStringAsFixed(4)}'),
                          const SizedBox(height: 4),
                          Text('${'weather.current'.tr()}: ${d.current.temperature.toStringAsFixed(1)}${_settings.getTemperatureUnit()}, ${'weather.wind'.tr()} ${d.current.windSpeed.toStringAsFixed(1)}${_settings.getWindSpeedUnit()}'),
                          if (d.current.humidity != null)
                            Text('${'weather.humidity'.tr()}: ${d.current.humidity!.toStringAsFixed(0)}%'),
                          if (d.current.pressure != null)
                            Text('${'weather.pressure'.tr()}: ${d.current.pressure!.toStringAsFixed(0)}${_settings.getPressureUnit()}'),
                          if (d.current.uvIndex != null)
                            Text('${'weather.uv_index'.tr()}: ${d.current.uvIndex!.toStringAsFixed(1)}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (lastName != null) Text('${'location.coordinates'.tr()}: $lastName')
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_favorites.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('app.favorites'.tr()),
                      ...List.generate(_favorites.length, (i){ final p=_favorites[i]; return ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(p.name), subtitle: Text(p.country),
                        onTap: ()=>_selectPlace(p),
                        trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async { final items = await _fav.removeAt(i); setState(()=>_favorites = items); }),
                      );}),
                    ],
                  ),
                ),
              ),
            TextField(
              decoration: InputDecoration(
                labelText: 'app.search'.tr(),
                hintText: 'location.search_placeholder'.tr(),
              ),
              controller: _searchCtrl,
              onChanged: (val) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _search(val));
              },
            ),
            const SizedBox(height: 8),
            if (_suggestions.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _suggestions
                        .take(5)
                        .map((e) => ListTile(
                              title: Text(e.name),
                              subtitle: Text(e.country),
                              onTap: () => _selectPlace(e),
                              trailing: IconButton(
                                icon: const Icon(Icons.star_border),
                                onPressed: () async {
                                  final items = await _fav.add(e);
                                  setState(() => _favorites = items);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children:[
                  Text('${'settings.units'.tr()}:'), const SizedBox(width: 8),
                  ElevatedButton(onPressed: ()=>_switchUnits(SettingsService.unitsMetric), child: Text('units.metric'.tr())),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: ()=>_switchUnits(SettingsService.unitsImperial), child: Text('units.imperial'.tr())),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('alerts.thresholds'.tr()),
                    Row(children:[
                      Text('alerts.wind_threshold'.tr()), Expanded(child: Slider(min: 0, max: 30, divisions: 30, value: alertWind, label: alertWind.toStringAsFixed(0), onChanged: (v){ setState(()=>alertWind=v); _persistThresholds(); })), Text(alertWind.toStringAsFixed(0))
                    ]),
                    Row(children:[
                      Text('alerts.precip_threshold'.tr()), Expanded(child: Slider(min: 0, max: 10, divisions: 20, value: alertPrecip, label: alertPrecip.toStringAsFixed(1), onChanged: (v){ setState(()=>alertPrecip=v); _persistThresholds(); })), Text(alertPrecip.toStringAsFixed(1))
                    ]),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(onPressed: (){ if (lastLat!=null && lastLon!=null){ setState(()=>loading=true); _loadFor(lastLat!, lastLon!, save: false); } }, icon: const Icon(Icons.refresh), label: Text('app.refresh'.tr())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'weather.hourly'.tr()} (first 12):'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 2,
                              spots: List.generate(d.hourly.take(12).length, (i) {
                                final h = d.hourly[i];
                                return FlSpot(i.toDouble(), h.temperature);
                              }),
                            ),
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 2,
                              spots: List.generate(d.hourly.take(12).length, (i) {
                                final h = d.hourly[i];
                                return FlSpot(i.toDouble(), h.windSpeed);
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'weather.daily'.tr()}:'),
                    const SizedBox(height: 8),
                    ...d.daily.map((day)=>Text('${_fullDateFormat.format(day.date)}: ${day.tempMin.toStringAsFixed(1)}..${day.tempMax.toStringAsFixed(1)}${_settings.getTemperatureUnit()}, ${'weather.precipitation'.tr()} ${day.precipitationSum.toStringAsFixed(1)}${_settings.getPrecipitationUnit()}')).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (marine != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${'marine.title'.tr()} (12h):'),
                      const SizedBox(height: 8),
                      ...marine!.data.hourly.take(12).map((h)=>Text('${_timeFormat.format(h.time)}  H=${h.waveHeight.toStringAsFixed(1)}${marine!.data.units.waveHeight}  P=${h.wavePeriod.toStringAsFixed(0)}${marine!.data.units.wavePeriod}  Dir=${h.waveDirection.toStringAsFixed(0)}${marine!.data.units.waveDirection}')).toList(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (alerts != null && alerts!.alerts.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${'alerts.title'.tr()} (next 24h):'),
                      const SizedBox(height: 8),
                      ...alerts!.alerts.take(10).map((al)=>Text('${_timeFormat.format(al.time)}: ${al.message} (value=${al.value.toStringAsFixed(1)}${al.unit})')).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFavs() async {
    final Place? p = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
    if (p != null) {
      setState(() { loading = true; });
      _selectPlace(p);
    }
  }

  void _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    // Reload settings after returning from settings screen
    await _loadSavedOrDefault();
  }
}

