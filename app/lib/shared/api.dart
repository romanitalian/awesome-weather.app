
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

class ApiClient {
  final Dio _dio;
  final String _baseUrl;
  
  ApiClient(String baseUrl)
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl, 
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 10),
        ));

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final fullUrl = '$_baseUrl$path';
    developer.log('API Request: GET $fullUrl', name: 'ApiClient');
    if (query != null) {
      developer.log('Query params: $query', name: 'ApiClient');
    }
    
    try {
      final response = await _dio.get(path, queryParameters: query);
      developer.log('API Response: ${response.statusCode} ${response.statusMessage}', name: 'ApiClient');
      return response;
    } catch (e) {
      developer.log('API Error: $e', name: 'ApiClient', error: e);
      rethrow;
    }
  }
}
