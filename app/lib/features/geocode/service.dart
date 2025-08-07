
import 'dart:convert';
import 'package:app/shared/api.dart';
import 'models.dart';

class GeocodeService {
  final ApiClient _api;
  GeocodeService(this._api);
  Future<GeocodeRS> search(String q) async {
    final r = await _api.get('/api/v1/geocode', query: {'q': q});
    final data = r.data is Map<String,dynamic> ? r.data as Map<String,dynamic> : jsonDecode(r.data as String) as Map<String,dynamic>;
    return GeocodeRS.fromJson(data);
  }
}
