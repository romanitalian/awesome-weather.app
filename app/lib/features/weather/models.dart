class WeatherUnits {
  final String temperature;
  final String windSpeed;
  final String windGust;
  final String windDirection;
  final String precipitation;
  final String pressure;
  final String cloudCover;
  
  const WeatherUnits({
    required this.temperature,
    required this.windSpeed,
    required this.windGust,
    required this.windDirection,
    required this.precipitation,
    required this.pressure,
    required this.cloudCover,
  });
  
  factory WeatherUnits.fromJson(Map<String, dynamic> json) => WeatherUnits(
    temperature: json['temperature'] as String,
    windSpeed: json['wind_speed'] as String,
    windGust: json['wind_gust'] as String,
    windDirection: json['wind_direction'] as String,
    precipitation: json['precipitation'] as String,
    pressure: json['pressure'] as String,
    cloudCover: json['cloud_cover'] as String,
  );
  
  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'wind_speed': windSpeed,
    'wind_gust': windGust,
    'wind_direction': windDirection,
    'precipitation': precipitation,
    'pressure': pressure,
    'cloud_cover': cloudCover,
  };
}

class Current {
  final DateTime time;
  final double temperature;
  final double windSpeed;
  final double windDirection;
  final double? humidity;
  final double? pressure;
  final double? cloudCover;
  final double? uvIndex;
  
  const Current({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    this.humidity,
    this.pressure,
    this.cloudCover,
    this.uvIndex,
  });
  
  factory Current.fromJson(Map<String, dynamic> json) => Current(
    time: DateTime.parse(json['time'] as String),
    temperature: (json['temperature'] as num).toDouble(),
    windSpeed: (json['wind_speed'] as num).toDouble(),
    windDirection: (json['wind_direction'] as num).toDouble(),
    humidity: json['humidity'] != null ? (json['humidity'] as num).toDouble() : null,
    pressure: json['pressure'] != null ? (json['pressure'] as num).toDouble() : null,
    cloudCover: json['cloud_cover'] != null ? (json['cloud_cover'] as num).toDouble() : null,
    uvIndex: json['uv_index'] != null ? (json['uv_index'] as num).toDouble() : null,
  );
  
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
    'wind_speed': windSpeed,
    'wind_direction': windDirection,
    if (humidity != null) 'humidity': humidity,
    if (pressure != null) 'pressure': pressure,
    if (cloudCover != null) 'cloud_cover': cloudCover,
    if (uvIndex != null) 'uv_index': uvIndex,
  };
}

class Hour {
  final DateTime time;
  final double temperature;
  final double windSpeed;
  final double? windGust;
  final double windDirection;
  final double precipitation;
  final double? pressure;
  final double? cloudCover;
  final double? humidity;
  final double? uvIndex;
  
  const Hour({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    this.windGust,
    required this.windDirection,
    required this.precipitation,
    this.pressure,
    this.cloudCover,
    this.humidity,
    this.uvIndex,
  });
  
  factory Hour.fromJson(Map<String, dynamic> json) => Hour(
    time: DateTime.parse(json['time'] as String),
    temperature: (json['temperature'] as num).toDouble(),
    windSpeed: (json['wind_speed'] as num).toDouble(),
    windGust: json['wind_gust'] != null ? (json['wind_gust'] as num).toDouble() : null,
    windDirection: (json['wind_direction'] as num).toDouble(),
    precipitation: (json['precipitation'] as num).toDouble(),
    pressure: json['pressure'] != null ? (json['pressure'] as num).toDouble() : null,
    cloudCover: json['cloud_cover'] != null ? (json['cloud_cover'] as num).toDouble() : null,
    humidity: json['humidity'] != null ? (json['humidity'] as num).toDouble() : null,
    uvIndex: json['uv_index'] != null ? (json['uv_index'] as num).toDouble() : null,
  );
  
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
    'wind_speed': windSpeed,
    if (windGust != null) 'wind_gust': windGust,
    'wind_direction': windDirection,
    'precipitation': precipitation,
    if (pressure != null) 'pressure': pressure,
    if (cloudCover != null) 'cloud_cover': cloudCover,
    if (humidity != null) 'humidity': humidity,
    if (uvIndex != null) 'uv_index': uvIndex,
  };
}

class Day {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double precipitationSum;
  final double windSpeedMax;
  final double? windGustsMax;
  final double windDirectionDominant;
  final DateTime sunrise;
  final DateTime sunset;
  final double? uvIndexMax;
  
  const Day({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationSum,
    required this.windSpeedMax,
    this.windGustsMax,
    required this.windDirectionDominant,
    required this.sunrise,
    required this.sunset,
    this.uvIndexMax,
  });
  
  factory Day.fromJson(Map<String, dynamic> json) => Day(
    date: DateTime.parse(json['date'] as String),
    tempMax: (json['temp_max'] as num).toDouble(),
    tempMin: (json['temp_min'] as num).toDouble(),
    precipitationSum: (json['precipitation_sum'] as num).toDouble(),
    windSpeedMax: (json['wind_speed_max'] as num).toDouble(),
    windGustsMax: json['wind_gusts_max'] != null ? (json['wind_gusts_max'] as num).toDouble() : null,
    windDirectionDominant: (json['wind_direction_dominant'] as num).toDouble(),
    sunrise: DateTime.parse(json['sunrise'] as String),
    sunset: DateTime.parse(json['sunset'] as String),
    uvIndexMax: json['uv_index_max'] != null ? (json['uv_index_max'] as num).toDouble() : null,
  );
  
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'temp_max': tempMax,
    'temp_min': tempMin,
    'precipitation_sum': precipitationSum,
    'wind_speed_max': windSpeedMax,
    if (windGustsMax != null) 'wind_gusts_max': windGustsMax,
    'wind_direction_dominant': windDirectionDominant,
    'sunrise': sunrise.toIso8601String(),
    'sunset': sunset.toIso8601String(),
    if (uvIndexMax != null) 'uv_index_max': uvIndexMax,
  };
}

class WeatherData {
  final double latitude;
  final double longitude;
  final String timezone;
  final WeatherUnits units;
  final Current current;
  final List<Hour> hourly;
  final List<Day> daily;
  
  const WeatherData({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.units,
    required this.current,
    required this.hourly,
    required this.daily,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    timezone: json['timezone'] as String,
    units: WeatherUnits.fromJson(json['units'] as Map<String, dynamic>),
    current: Current.fromJson(json['current'] as Map<String, dynamic>),
    hourly: (json['hourly'] as List<dynamic>).map((e) => Hour.fromJson(e as Map<String, dynamic>)).toList(),
    daily: (json['daily'] as List<dynamic>).map((e) => Day.fromJson(e as Map<String, dynamic>)).toList(),
  );
  
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'units': units.toJson(),
    'current': current.toJson(),
    'hourly': hourly.map((e) => e.toJson()).toList(),
    'daily': daily.map((e) => e.toJson()).toList(),
  };
}

class WeatherRS {
  final String source;
  final DateTime issued;
  final WeatherData data;
  
  const WeatherRS({
    required this.source,
    required this.issued,
    required this.data,
  });
  
  factory WeatherRS.fromJson(Map<String, dynamic> json) => WeatherRS(
    source: json['source'] as String,
    issued: DateTime.parse(json['issued'] as String),
    data: WeatherData.fromJson(json['data'] as Map<String, dynamic>),
  );
  
  Map<String, dynamic> toJson() => {
    'source': source,
    'issued': issued.toIso8601String(),
    'data': data.toJson(),
  };
}
