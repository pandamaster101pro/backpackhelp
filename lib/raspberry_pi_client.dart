import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RaspberryPiException implements Exception {
  final String message;

  const RaspberryPiException(this.message);

  @override
  String toString() => message;
}

class RaspberryPiClient {
  RaspberryPiClient._();

  static final RaspberryPiClient instance = RaspberryPiClient._();
  static const _urlKey = 'raspberry_pi_url';
  static const _apiKeyKey = 'raspberry_pi_api_key';
  static const defaultUrl = 'http://raspberrypi.local:8000';

  Future<String> getBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_urlKey) ?? defaultUrl;
  }

  Future<String> getApiKey() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_apiKeyKey) ?? '';
  }

  Future<void> saveSettings(String url, String apiKey) async {
    final normalizedUrl = _normalizeUrl(url);
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.host.isEmpty || !uri.hasPort) {
      throw const RaspberryPiException(
        'Enter a complete address including port 8000.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, normalizedUrl);
    await preferences.setString(_apiKeyKey, apiKey.trim());
  }

  Future<void> testConnection() async {
    final response = await _get('/health');
    if (response.statusCode != 200) {
      throw RaspberryPiException('Pi returned HTTP ${response.statusCode}.');
    }
  }

  Future<List<String>> scan({int seconds = 8}) async {
    final response = await _post('/scan', {'seconds': seconds});
    if (response.statusCode != 200) {
      throw RaspberryPiException(
        _errorFrom(response, 'Pi returned HTTP ${response.statusCode}.'),
      );
    }

    final body = jsonDecode(response.body);
    final items = body is Map<String, dynamic> ? body['items'] : null;
    if (items is! List) {
      throw const RaspberryPiException('Pi returned an invalid scan response.');
    }
    return items.map((item) => item.toString()).toList();
  }

  Future<http.Response> _get(String path) async {
    try {
      final baseUrl = await getBaseUrl();
      final apiKey = await getApiKey();
      return await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {if (apiKey.isNotEmpty) 'X-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      throw const RaspberryPiException(
        'Could not reach the Raspberry Pi. Check its address and network.',
      );
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      final baseUrl = await getBaseUrl();
      final apiKey = await getApiKey();
      return await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));
    } catch (_) {
      throw const RaspberryPiException(
        'Could not reach the Raspberry Pi. Check its address and network.',
      );
    }
  }

  String _normalizeUrl(String value) {
    var url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  String _errorFrom(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
