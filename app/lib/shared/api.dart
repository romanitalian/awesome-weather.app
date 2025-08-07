
import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  ApiClient(String baseUrl)
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 6)));

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    return _dio.get(path, queryParameters: query);
  }
}
