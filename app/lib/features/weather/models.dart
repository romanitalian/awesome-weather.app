
class WeatherUnits {
  final String temperature;
  final String windSpeed;
  final String windGust;
  final String windDirection;
  final String precipitation;
  final String pressure;
  final String cloudCover;
  const WeatherUnits({required this.temperature,required this.windSpeed,required this.windGust,required this.windDirection,required this.precipitation,required this.pressure,required this.cloudCover});
  factory WeatherUnits.fromJson(Map<String,dynamic> j)=>WeatherUnits(
    temperature: j['temperature'] as String,
    windSpeed: j['wind_speed'] as String,
    windGust: j['wind_gust'] as String,
    windDirection: j['wind_direction'] as String,
    precipitation: j['precipitation'] as String,
    pressure: j['pressure'] as String,
    cloudCover: j['cloud_cover'] as String,
  );
}
class Current { final String time; final double temperature; final double windSpeed; final double windDirection; const Current({required this.time,required this.temperature,required this.windSpeed,required this.windDirection}); factory Current.fromJson(Map<String,dynamic> j)=>Current(time:j['time'] as String,temperature:(j['temperature'] as num).toDouble(),windSpeed:(j['wind_speed'] as num).toDouble(),windDirection:(j['wind_direction'] as num).toDouble()); }
class Hour { final String time; final double temperature; final double windSpeed; final double windGust; final double windDirection; final double precipitation; final double pressure; final double cloudCover; const Hour({required this.time,required this.temperature,required this.windSpeed,required this.windGust,required this.windDirection,required this.precipitation,required this.pressure,required this.cloudCover}); factory Hour.fromJson(Map<String,dynamic> j)=>Hour(time:j['time'] as String,temperature:(j['temperature'] as num).toDouble(),windSpeed:(j['wind_speed'] as num).toDouble(),windGust:(j['wind_gust'] as num).toDouble(),windDirection:(j['wind_direction'] as num).toDouble(),precipitation:(j['precipitation'] as num).toDouble(),pressure:(j['pressure'] as num).toDouble(),cloudCover:(j['cloud_cover'] as num).toDouble()); }
class Day { final String date; final double tempMax; final double tempMin; final double precipitationSum; final double windSpeedMax; final double windGustsMax; final double windDirectionDominant; final String sunrise; final String sunset; const Day({required this.date,required this.tempMax,required this.tempMin,required this.precipitationSum,required this.windSpeedMax,required this.windGustsMax,required this.windDirectionDominant,required this.sunrise,required this.sunset}); factory Day.fromJson(Map<String,dynamic> j)=>Day(date:j['date'] as String,tempMax:(j['temp_max'] as num).toDouble(),tempMin:(j['temp_min'] as num).toDouble(),precipitationSum:(j['precipitation_sum'] as num).toDouble(),windSpeedMax:(j['wind_speed_max'] as num).toDouble(),windGustsMax:(j['wind_gusts_max'] as num).toDouble(),windDirectionDominant:(j['wind_direction_dominant'] as num).toDouble(),sunrise:j['sunrise'] as String,sunset:j['sunset'] as String); }
class WeatherData { final double latitude; final double longitude; final String timezone; final WeatherUnits units; final Current current; final List<Hour> hourly; final List<Day> daily; const WeatherData({required this.latitude,required this.longitude,required this.timezone,required this.units,required this.current,required this.hourly,required this.daily}); factory WeatherData.fromJson(Map<String,dynamic> j)=>WeatherData(latitude:(j['latitude'] as num).toDouble(),longitude:(j['longitude'] as num).toDouble(),timezone:j['timezone'] as String,units:WeatherUnits.fromJson(j['units']),current:Current.fromJson(j['current']),hourly:(j['hourly'] as List).map((e)=>Hour.fromJson(e)).toList(),daily:(j['daily'] as List).map((e)=>Day.fromJson(e)).toList()); }
class WeatherRS { final String source; final String issued; final WeatherData data; const WeatherRS({required this.source,required this.issued,required this.data}); factory WeatherRS.fromJson(Map<String,dynamic> j)=>WeatherRS(source:j['source'] as String,issued:j['issued'] as String,data:WeatherData.fromJson(j['data'])); }
