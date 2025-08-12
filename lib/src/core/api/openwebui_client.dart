import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class OpenWebUIClient {
  OpenWebUIClient(this._prefs, this._secure);

  static const _kBaseUrlKey = 'base_url';
  static const _kTokenKey = 'auth_token';
  static const _kRememberKey = 'remember_me';
  static const _kCredEmail = 'cred_email';
  static const _kCredPassword = 'cred_password';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  String? get baseUrl => _prefs.getString(_kBaseUrlKey);
  Future<String?> get token async => await _secure.read(key: _kTokenKey);

  Future<void> setBaseUrl(String url) async {
    final normalized =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _prefs.setString(_kBaseUrlKey, normalized);
  }

  Future<void> setToken(String token) async {
    await _secure.write(key: _kTokenKey, value: token);
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _kTokenKey);
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
    required bool remember,
  }) async {
    await _prefs.setBool(_kRememberKey, remember);
    if (remember) {
      await _secure.write(key: _kCredEmail, value: email);
      await _secure.write(key: _kCredPassword, value: password);
    } else {
      await _secure.delete(key: _kCredEmail);
      await _secure.delete(key: _kCredPassword);
    }
  }

  Future<bool> trySilentReauth() async {
    final remember = _prefs.getBool(_kRememberKey) ?? false;
    if (!remember) return false;
    final email = await _secure.read(key: _kCredEmail);
    final password = await _secure.read(key: _kCredPassword);
    if (email == null || password == null) return false;
    try {
      await signIn(email: email, password: password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyBaseUrl() async {
    final url = baseUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse('$url/api/config');

    final res = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            throw const ApiException('Timeout while verifying base URL');
          },
        );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    throw ApiException('Invalid server response', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths/signin');

    final res = await http
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw const ApiException('Timeout during sign in');
          },
        );

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = body['token'] as String?;
      if (token != null) {
        await setToken(token);
      }
      return body as Map<String, dynamic>;
    }
    throw ApiException(
      body is Map && body['detail'] is String
          ? body['detail']
          : 'Sign-in failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> getSessionUser() async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths');

    final res = await http.get(uri, headers: await _authHeaders());
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException(
      body is Map && body['detail'] is String ? body['detail'] : 'Unauthorized',
      statusCode: res.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> listChats() async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats');
    final res = await http.get(uri, headers: await _authHeaders());
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : [];
    if (res.statusCode >= 200 && res.statusCode < 300) {
      print('listChats: $body');
      return (body as List).cast<Map<String, dynamic>>();
    }
    throw ApiException('Failed to load chats', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getChatById(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id');
    final res = await http.get(uri, headers: await _authHeaders());
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to load chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> createChat({
    required Map<String, dynamic> chat,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/new');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'chat': chat}),
    );
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to create chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> renameChat({
    required String id,
    required String title,
  }) async {
    // Update via full chat payload: fetch -> modify title -> PUT via POST /{id}
    final chat = await getChatById(id);
    final chatPayload = Map<String, dynamic>.from(chat['chat'] as Map);
    chatPayload['title'] = title;
    return updateChat(id: id, chat: chatPayload);
  }

  Future<Map<String, dynamic>> updateChat({
    required String id,
    required Map<String, dynamic> chat,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'chat': chat}),
    );
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to update chat', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> listModels({bool refresh = false}) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final qp = refresh ? '?refresh=true' : '';
    final uri = Uri.parse('$url/api/models$qp');
    final res = await http.get(uri, headers: await _authHeaders());
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = body['data'] as List? ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    throw ApiException('Failed to load models', statusCode: res.statusCode);
  }

  Future<http.StreamedResponse> streamChatCompletion({
    required Map<String, dynamic> payload,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final request = http.Request(
      'POST',
      Uri.parse('$url/api/chat/completions'),
    );
    request.headers.addAll(await _authHeaders());
    request.body = jsonEncode(payload);
    return request.send();
  }

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final t = await token;
    if (t != null && t.isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postChatCompleted(
    Map<String, dynamic> body,
  ) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/chat/completed');
    final res = await http
        .post(uri, headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final text = res.body;
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw ApiException(
        'Server returned HTML for /chat/completed',
        statusCode: res.statusCode,
      );
    }
    final data = text.isNotEmpty ? jsonDecode(text) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException('chat/completed failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> postAutoCompletion(
    Map<String, dynamic> body,
  ) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/tasks/auto/completions');
    final res = await http
        .post(uri, headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final text = res.body;
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw ApiException(
        'Server returned HTML for tasks/auto/completions',
        statusCode: res.statusCode,
      );
    }
    final data = text.isNotEmpty ? jsonDecode(text) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(
      'tasks/auto/completions failed',
      statusCode: res.statusCode,
    );
  }
}

final openWebUIClientProvider = FutureProvider<OpenWebUIClient>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();
  return OpenWebUIClient(prefs, secure);
});
