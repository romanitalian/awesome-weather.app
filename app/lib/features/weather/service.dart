
import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class WeatherService {
  final ApiClient _api;
  WeatherService(this._api);
  
  Future<WeatherRS> fetch({required double lat, required double lon, String units = 'metric'}) async {
    final q = {'lat': lat, 'lon': lon, 'units': units};
    developer.log('WeatherService.fetch called with lat=$lat, lon=$lon, units=$units', name: 'WeatherService');
    
    try {
      developer.log('Making API request...', name: 'WeatherService');
      final r = await _api.get('/api/v1/weather', query: q);
      developer.log('API request successful: ${r.statusCode}', name: 'WeatherService');
      
      final xCache = r.headers.map['x-cache']?.join(',') ?? '';
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : jsonDecode(r.data as String) as Map<String, dynamic>;
      
      developer.log('Parsed response data successfully', name: 'WeatherService');
      
      // cache last response
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_weather_rs', jsonEncode(data));
      await prefs.setString('last_weather_x_cache', xCache);
      
      developer.log('Cached response data', name: 'WeatherService');
      return WeatherRS.fromJson(data);
    } catch (e) {
      developer.log('API request failed: $e', name: 'WeatherService', error: e);
      
      // offline fallback
      developer.log('Trying offline fallback...', name: 'WeatherService');
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_weather_rs');
      if (s != null && s.isNotEmpty) {
        developer.log('Using cached data', name: 'WeatherService');
        final data = jsonDecode(s) as Map<String, dynamic>;
        return WeatherRS.fromJson(data);
      }
      
      developer.log('No cached data available, rethrowing error', name: 'WeatherService');
      rethrow;
    }
  }
}
