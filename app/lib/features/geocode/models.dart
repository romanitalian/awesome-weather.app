
class Place { final String name; final double lat; final double lon; final String country; const Place({required this.name, required this.lat, required this.lon, required this.country}); factory Place.fromJson(Map<String,dynamic> j)=>Place(name:j['name'] as String, lat:(j['latitude'] as num).toDouble(), lon:(j['longitude'] as num).toDouble(), country:(j['country']??'') as String); @override String toString()=> '$name, $country (${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)})'; }
class GeocodeRS { final List<Place> results; const GeocodeRS(this.results); factory GeocodeRS.fromJson(Map<String,dynamic> j){ final lst=(j['results'] as List? )?? []; return GeocodeRS(lst.map((e)=>Place.fromJson(e)).toList()); }
}
