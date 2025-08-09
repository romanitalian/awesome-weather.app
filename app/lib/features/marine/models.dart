class MarineUnits {
  final String waveHeight;
  final String wavePeriod;
  final String waveDirection;
  final String swellHeight;
  final String swellPeriod;
  final String swellDirection;
  const MarineUnits({
    required this.waveHeight,
    required this.wavePeriod,
    required this.waveDirection,
    required this.swellHeight,
    required this.swellPeriod,
    required this.swellDirection,
  });
  factory MarineUnits.fromJson(Map<String, dynamic> j) => MarineUnits(
        waveHeight: j['wave_height'] as String,
        wavePeriod: j['wave_period'] as String,
        waveDirection: j['wave_direction'] as String,
        swellHeight: j['swell_height'] as String,
        swellPeriod: j['swell_period'] as String,
        swellDirection: j['swell_direction'] as String,
      );
}

class MarineHour {
  final DateTime time;
  final double waveHeight;
  final double wavePeriod;
  final double waveDirection;
  final double swellHeight;
  final double swellPeriod;
  final double swellDirection;
  const MarineHour({
    required this.time,
    required this.waveHeight,
    required this.wavePeriod,
    required this.waveDirection,
    required this.swellHeight,
    required this.swellPeriod,
    required this.swellDirection,
  });
  factory MarineHour.fromJson(Map<String, dynamic> j) => MarineHour(
        time: DateTime.parse(j['time'] as String),
        waveHeight: (j['wave_height'] as num).toDouble(),
        wavePeriod: (j['wave_period'] as num).toDouble(),
        waveDirection: (j['wave_direction'] as num).toDouble(),
        swellHeight: (j['swell_height'] as num).toDouble(),
        swellPeriod: (j['swell_period'] as num).toDouble(),
        swellDirection: (j['swell_direction'] as num).toDouble(),
      );
}

class MarineData {
  final double latitude;
  final double longitude;
  final String timezone;
  final MarineUnits units;
  final List<MarineHour> hourly;
  const MarineData({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.units,
    required this.hourly,
  });
  factory MarineData.fromJson(Map<String, dynamic> j) => MarineData(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        timezone: j['timezone'] as String,
        units: MarineUnits.fromJson(j['units'] as Map<String, dynamic>),
        hourly: (j['hourly'] as List).map((e) => MarineHour.fromJson(e)).toList(),
      );
}

class MarineRS {
  final String source;
  final DateTime issued;
  final MarineData data;
  const MarineRS({required this.source, required this.issued, required this.data});
  factory MarineRS.fromJson(Map<String, dynamic> j) => MarineRS(
        source: j['source'] as String,
        issued: DateTime.parse(j['issued'] as String),
        data: MarineData.fromJson(j['data'] as Map<String, dynamic>),
      );
}


