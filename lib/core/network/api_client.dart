import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiClient {
  static const String _tokenKey = 'jwt_token';
  
  // Cấu hình AndroidOptions an toàn chống mất token khi tắt app
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  String? _inMemoryToken;

  Future<String?> getToken() async {
    if (_inMemoryToken != null && _inMemoryToken!.isNotEmpty) {
      return _inMemoryToken;
    }
    try {
      final token = await _storage.read(key: _tokenKey);
      _inMemoryToken = token;
      return token;
    } catch (e) {
      debugPrint('Lỗi đọc token từ SecureStorage: $e');
      return _inMemoryToken;
    }
  }

  Future<void> saveToken(String token) async {
    _inMemoryToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('Lỗi ghi token vào SecureStorage: $e');
    }
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('Lỗi xóa token: $e');
    }
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String url) async {
    try {
      final token = await getToken();
      final response = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String url, dynamic body) async {
    try {
      final token = await getToken();
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(String url, dynamic body) async {
    try {
      final token = await getToken();
      final response = await http
          .put(
            Uri.parse(url),
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> delete(String url) async {
    try {
      final token = await getToken();
      final response = await http
          .delete(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadFile(String endpoint, File file, String fieldName) async {
    try {
      final token = await getToken();
      final uri = Uri.parse(endpoint);

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final ext = file.path.split('.').last.toLowerCase();
      final mimeSubType = (ext == 'png') ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          contentType: MediaType('image', mimeSubType),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response) as Map<String, dynamic>;
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Thời gian tải ảnh quá lâu. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadBytes(
    String endpoint,
    List<int> bytes,
    String filename,
    String fieldName,
  ) async {
    try {
      final token = await getToken();
      final uri = Uri.parse(endpoint);

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final ext = filename.split('.').last.toLowerCase();
      final mimeSubType = (ext == 'png') ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: MediaType('image', mimeSubType),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response) as Map<String, dynamic>;
    } on SocketException {
      throw 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
    } on TimeoutException {
      throw 'Thời gian tải ảnh quá lâu. Vui lòng thử lại.';
    } catch (e) {
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final bodyString = response.body;

    debugPrint('🌐 [API Response - $statusCode]: $bodyString');

    if (bodyString.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) return {};
      throw 'Máy chủ phản hồi rỗng (Mã lỗi: $statusCode)';
    }

    if (bodyString.trim().startsWith('<')) {
      throw 'Hệ thống đang bảo trì hoặc địa chỉ API chưa chính xác.';
    }

    try {
      final decoded = jsonDecode(bodyString);
      if (statusCode >= 200 && statusCode < 300) {
        return decoded;
      } else {
        final msg = decoded is Map ? (decoded['message'] ?? decoded['error']) : null;
        throw (msg?.toString().trim().isNotEmpty == true)
            ? msg.toString()
            : 'Yêu cầu không thành công (Mã lỗi: $statusCode)';
      }
    } catch (e) {
      if (e is String) throw e;
      throw 'Dữ liệu phản hồi từ máy chủ không hợp lệ.';
    }
  }
}