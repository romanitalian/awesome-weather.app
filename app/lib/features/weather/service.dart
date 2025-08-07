
import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  final ApiClient _api;
  WeatherService(this._api);
  Future<WeatherRS> fetch({required double lat, required double lon, String units = 'metric'}) async {
    final q = {'lat': lat, 'lon': lon, 'units': units};
    try {
      final r = await _api.get('/api/v1/weather', query: q);
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : jsonDecode(r.data as String) as Map<String, dynamic>;
      // cache last response
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_weather_rs', jsonEncode(data));
      return WeatherRS.fromJson(data);
    } catch (e) {
      // offline fallback
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_weather_rs');
      if (s != null && s.isNotEmpty) {
        final data = jsonDecode(s) as Map<String, dynamic>;
        return WeatherRS.fromJson(data);
      }
      rethrow;
    }
  }
}
