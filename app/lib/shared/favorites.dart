import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/geocode/models.dart';

class FavoritesStore {
  static const _key = 'favorites_v1';

  Future<List<Place>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null || s.isEmpty) return <Place>[];
    final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    return list.map((e) => Place.fromJson(e)).toList();
  }

  Future<void> save(List<Place> places) async {
    final p = await SharedPreferences.getInstance();
    final list = places
        .map((e) => {
              'name': e.name,
              'latitude': e.lat,
              'longitude': e.lon,
              'country': e.country,
            })
        .toList();
    await p.setString(_key, jsonEncode(list));
  }

  Future<List<Place>> add(Place place) async {
    final items = await load();
    final exists = items.any((e) => (e.lat == place.lat && e.lon == place.lon));
    if (!exists) {
      items.add(place);
      await save(items);
    }
    return items;
  }

  Future<List<Place>> removeAt(int index) async {
    final items = await load();
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      await save(items);
    }
    return items;
  }
}


