import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertsService {
  final ApiClient _api;
  AlertsService(this._api);
  Future<AlertsRS> fetch({required double lat, required double lon, String units = 'metric', double windSpeedGte = 10.0, double precipGte = 1.0}) async {
    final q = {
      'lat': lat,
      'lon': lon,
      'units': units,
      'wind_speed_gte': windSpeedGte,
      'precip_gte': precipGte,
    };
    try {
      final r = await _api.get('/api/v1/alerts', query: q);
      final data = r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : jsonDecode(r.data as String) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_alerts_rs', jsonEncode(data));
      return AlertsRS.fromJson(data);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_alerts_rs');
      if (s != null && s.isNotEmpty) {
        return AlertsRS.fromJson(jsonDecode(s) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
