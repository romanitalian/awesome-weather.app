class AlertItem {
  final String type;
  final DateTime time;
  final double value;
  final String unit;
  final String message;
  const AlertItem({required this.type, required this.time, required this.value, required this.unit, required this.message});
  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
    type: j['type'] as String,
    time: DateTime.parse(j['time'] as String),
    value: (j['value'] as num).toDouble(),
    unit: j['unit'] as String,
    message: j['message'] as String,
  );
}

class AlertsRS {
  final String source;
  final DateTime issued;
  final List<AlertItem> alerts;
  const AlertsRS({required this.source, required this.issued, required this.alerts});
  factory AlertsRS.fromJson(Map<String, dynamic> j) => AlertsRS(
    source: j['source'] as String,
    issued: DateTime.parse(j['issued'] as String),
    alerts: (j['alerts'] as List).map((e) => AlertItem.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
