import 'dart:convert';
import 'package:flutter/foundation.dart';

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
  // We only persist the JWT token, not the password. Email saved only for UX if needed.
  static const _kRememberKey = 'remember_me';
  static const _kCredEmail = 'cred_email';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  Map<String, dynamic>? _cachedSessionUser;

  String? get baseUrl => _prefs.getString(_kBaseUrlKey);
  Future<String?> get token async => await _secure.read(key: _kTokenKey);

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[OpenWebUIClient] $message');
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'null';
    final at = email.indexOf('@');
    if (at <= 1) return '***@${at > 0 ? email.substring(at + 1) : 'unknown'}';
    return '${email.substring(0, 1)}***${email.substring(at - 1)}';
  }

  String _maskToken(String? t) {
    if (t == null || t.isEmpty) return 'null';
    final start = t.substring(0, t.length < 6 ? t.length : 6);
    final end = t.length > 4 ? t.substring(t.length - 4) : '';
    return 'len=${t.length}, $start...$end';
  }

  Future<void> setBaseUrl(String url) async {
    final normalized =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _log('setBaseUrl -> $normalized');
    await _prefs.setString(_kBaseUrlKey, normalized);
  }

  Future<void> setToken(String token) async {
    _log('setToken -> ${_maskToken(token)}');
    await _secure.write(key: _kTokenKey, value: token);
  }

  Future<void> clearSession() async {
    _log('clearSession -> deleting token');
    await _secure.delete(key: _kTokenKey);
  }

  Future<void> saveEmailForUX({required String email}) async {
    _log('saveEmailForUX email=${_maskEmail(email)}');
    await _prefs.setBool(_kRememberKey, true);
    await _secure.write(key: _kCredEmail, value: email);
  }

  Future<bool> trySilentReauth() async {
    // Do not re-use password. If token exists, it should be valid until expiry.
    // We just validate current token; if invalid/expired, we cannot auto-login without credentials.
    final t = await token;
    _log('trySilentReauth -> tokenPresent=${t != null && t.isNotEmpty}');
    if (t == null || t.isEmpty) return false;
    try {
      await getSessionUser();
      _log('trySilentReauth -> token valid');
      return true;
    } catch (e) {
      _log('trySilentReauth -> token invalid: $e');
      return false;
    }
  }

  Future<bool> verifyBaseUrl() async {
    final url = baseUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse('$url/api/config');
    _log('verifyBaseUrl GET $uri');

    final res = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            throw const ApiException('Timeout while verifying base URL');
          },
        );
    _log(
      'verifyBaseUrl <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    throw ApiException('Invalid server response', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getServerConfig() async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/config');
    _log('getServerConfig GET $uri');
    final res = await http.get(uri);
    _log(
      'getServerConfig <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException(
      'Failed to load server config',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths/signin');
    _log('signIn POST $uri email=${_maskEmail(email)}');

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
    _log(
      'signIn <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = body['token'] as String?;
      if (token != null) {
        await setToken(token);
        _log('signIn stored token: ${_maskToken(token)}');
      }
      return body;
    }
    _log(
      'signIn failed <- ${res.statusCode} body=${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}',
    );
    throw ApiException(
      body is Map && body['detail'] is String
          ? body['detail']
          : 'Sign-in failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> getSessionUser() async {
    if (_cachedSessionUser != null) {
      _log('getSessionUser cache hit');
      return _cachedSessionUser!;
    }
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths/');
    _log('getSessionUser GET $uri');

    final headers = await _authHeaders();
    final res = await http.get(uri, headers: headers);
    final contentType = res.headers['content-type'] ?? '';
    _log('getSessionUser <- ${res.statusCode} content-type=$contentType');
    if (contentType.contains('text/html')) {
      throw ApiException(
        'Server returned HTML for /v1/auths',
        statusCode: res.statusCode,
      );
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _cachedSessionUser = (body as Map).cast<String, dynamic>();
      return _cachedSessionUser!;
    }
    throw ApiException(
      body is Map && body['detail'] is String ? body['detail'] : 'Unauthorized',
      statusCode: res.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> listChats({int? page}) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final qp = page != null ? '?page=$page' : '';
    final uri = Uri.parse('$url/api/v1/chats/$qp');
    _log('listChats GET $uri');
    final headers = await _authHeaders();
    _log(
      'listChats headers -> hasAuth=${headers.containsKey('Authorization')}',
    );
    final res = await http.get(uri, headers: headers);
    _log(
      'listChats <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw ApiException(
        'Server returned HTML for /v1/chats',
        statusCode: res.statusCode,
      );
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : [];
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = body as List;
      _log('listChats ok, count=${list.length}');
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException('Failed to load chats', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getChatById(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id');
    _log('getChatById GET $uri');
    final res = await http.get(uri, headers: await _authHeaders());
    _log(
      'getChatById <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
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
    _log('createChat POST $uri payloadKeys=${chat.keys.toList()}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'chat': chat}),
    );
    _log(
      'createChat <- ${res.statusCode} content-type=${res.headers['content-type']}',
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
    _log('renameChat id=$id title="$title"');
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
    _log('updateChat POST $uri payloadKeys=${chat.keys.toList()}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'chat': chat}),
    );
    _log(
      'updateChat <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to update chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> pinChat(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id/pin');
    _log('pinChat POST $uri');
    final res = await http.post(uri, headers: await _authHeaders());
    _log('pinChat <- ${res.statusCode}');
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to pin chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> archiveChat(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id/archive');
    _log('archiveChat POST $uri');
    final res = await http.post(uri, headers: await _authHeaders());
    _log('archiveChat <- ${res.statusCode}');
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to archive chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> cloneChat(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id/clone');
    _log('cloneChat POST $uri');
    final res = await http.post(uri, headers: await _authHeaders());
    _log('cloneChat <- ${res.statusCode}');
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to clone chat', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> shareChat(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id/share');
    _log('shareChat POST $uri');
    final res = await http.post(uri, headers: await _authHeaders());
    _log('shareChat <- ${res.statusCode}');
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to share chat', statusCode: res.statusCode);
  }

  Future<bool> deleteChat(String id) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/$id');
    _log('deleteChat DELETE $uri');
    final res = await http.delete(uri, headers: await _authHeaders());
    _log('deleteChat <- ${res.statusCode}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    throw ApiException('Failed to delete chat', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> listModels({bool refresh = false}) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final qp = refresh ? '?refresh=true' : '';
    final uri = Uri.parse('$url/api/models$qp');
    _log('listModels GET $uri');
    final res = await http.get(uri, headers: await _authHeaders());
    _log(
      'listModels <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
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
    // Include session_id to align with WebUI socket usage when available
    final withSession = Map<String, dynamic>.from(payload);
    try {
      final sess = _cachedSessionUser ?? await getSessionUser();
      final socketId = (sess['socket_id'] as String?);
      withSession['session_id'] = socketId ?? '';
    } catch (_) {
      withSession['session_id'] = '';
    }
    request.body = jsonEncode(withSession);
    _log(
      'streamChatCompletion POST ${request.url} headersAuth=${request.headers.containsKey('Authorization')}',
    );
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
      // Some deployments rely on cookie auth; include token cookie to match WebUI behavior
      headers['Cookie'] = 'token=$t';
    }
    _log(
      '_authHeaders -> hasAuth=${headers.containsKey('Authorization')} token=${_maskToken(t)}',
    );
    return headers;
  }

  Future<Map<String, dynamic>> postChatCompleted(
    Map<String, dynamic> body,
  ) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/chat/completed');
    _log('postChatCompleted POST $uri');
    final res = await http
        .post(uri, headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    _log(
      'postChatCompleted <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
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
    _log('postAutoCompletion POST $uri');
    final res = await http
        .post(uri, headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    _log(
      'postAutoCompletion <- ${res.statusCode} content-type=${res.headers['content-type']}',
    );
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

  Future<String?> generateTitle({
    required String model,
    required List<Map<String, dynamic>> messages,
    String? chatId,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/tasks/title/completions');
    _log('generateTitle POST $uri');
    final res = await http
        .post(
          uri,
          headers: await _authHeaders(),
          body: jsonEncode({
            'model': model,
            'messages': messages,
            if (chatId != null) 'chat_id': chatId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw const ApiException(
        'Server returned HTML for tasks/title/completions',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = jsonDecode(res.body);
        final content =
            body['choices']?[0]?['message']?['content'] as String? ?? '';
        if (content.isEmpty) return null;
        final sanitized = content.replaceAll(RegExp("['‘’`]"), '"');
        final start = sanitized.indexOf('{');
        final end = sanitized.lastIndexOf('}');
        if (start != -1 && end != -1) {
          final jsonBlock = sanitized.substring(start, end + 1);
          final parsed = jsonDecode(jsonBlock);
          final title = parsed['title'] as String?;
          return title?.trim();
        }
      } catch (e) {
        _log('generateTitle parse error: $e');
      }
      return null;
    }
    throw ApiException('title/completions failed', statusCode: res.statusCode);
  }

  Future<int> getActiveUsersCount() async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/users/active');
    _log('getActiveUsersCount GET $uri');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw const ApiException('Server returned HTML for users/active');
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final ids = (body['user_ids'] as List? ?? const []);
      return ids.length;
    }
    throw ApiException(
      'Failed to load active users',
      statusCode: res.statusCode,
    );
  }

  Future<void> signOut() async {
    final url = baseUrl;
    if (url == null) return;
    final uri = Uri.parse('$url/api/v1/auths/signout');
    _log('signOut GET $uri');
    try {
      await http.get(uri, headers: await _authHeaders());
    } catch (e) {
      _log('signOut request error: $e');
    }
    await clearSession();
  }

  Future<List<Map<String, dynamic>>> listArchivedChats() async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/chats/all/archived');
    _log('listArchivedChats GET $uri');
    final res = await http.get(uri, headers: await _authHeaders());
    final contentType = res.headers['content-type'] ?? '';
    _log('listArchivedChats <- ${res.statusCode} content-type=$contentType');
    if (contentType.contains('text/html')) {
      throw ApiException(
        'Server returned HTML for archived chats',
        statusCode: res.statusCode,
      );
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : [];
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = body as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(
      'Failed to load archived chats',
      statusCode: res.statusCode,
    );
  }

  // Settings / Profile APIs
  Future<Map<String, dynamic>> getSessionProfile() async {
    return await getSessionUser();
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String profileImageUrl,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths/update/profile');
    _log('updateProfile POST $uri');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'name': name, 'profile_image_url': profileImageUrl}),
    );
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw const ApiException('Server returned HTML for update/profile');
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException('Failed to update profile', statusCode: res.statusCode);
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = baseUrl;
    if (url == null) throw const ApiException('Base URL not set');
    final uri = Uri.parse('$url/api/v1/auths/update/password');
    _log('updatePassword POST $uri');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.headers['content-type']?.contains('text/html') == true) {
      throw const ApiException('Server returned HTML for update/password');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    throw ApiException('Failed to update password', statusCode: res.statusCode);
  }
}

final openWebUIClientProvider = FutureProvider<OpenWebUIClient>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();
  return OpenWebUIClient(prefs, secure);
});

final sessionUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = await ref.watch(openWebUIClientProvider.future);
  return client.getSessionUser();
});
