import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarineService {
  final ApiClient _api;
  MarineService(this._api);
  Future<MarineRS> fetch({required double lat, required double lon}) async {
    try {
      final r = await _api.get('/api/v1/marine', query: {'lat': lat, 'lon': lon});
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : jsonDecode(r.data as String) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_marine_rs', jsonEncode(data));
      return MarineRS.fromJson(data);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('last_marine_rs');
      if (s != null && s.isNotEmpty) {
        return MarineRS.fromJson(jsonDecode(s) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}


