import 'package:flutter/material.dart';
import 'features/weather/screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const api = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8080');
    return const MaterialApp(
      home: WeatherScreen(apiBaseUrl: api),
    );
  }
}
