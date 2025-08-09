import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TidesService {
  final ApiClient _api;
  TidesService(this._api);
  Future<TidesRS> fetch({required double lat, required double lon}) async {
    try {
      final r = await _api.get('/api/v1/tides', query: {'lat': lat, 'lon': lon});
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : jsonDecode(r.data as String) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_tides_rs', jsonEncode(data));
      return TidesRS.fromJson(data);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_tides_rs');
      if (s != null && s.isNotEmpty) {
        return TidesRS.fromJson(jsonDecode(s) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
