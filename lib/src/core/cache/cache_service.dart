import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  CacheService(this._prefs);

  final SharedPreferences _prefs;

  Future<void> setJson(String key, Object value) async {
    await _prefs.setString(
      key,
      jsonEncode({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'data': value,
      }),
    );
  }

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  T? getData<T>(String key) {
    final wrapped = getJson(key);
    return wrapped == null ? null : wrapped['data'] as T?;
  }

  int? getUpdatedAt(String key) {
    final wrapped = getJson(key);
    return wrapped == null ? null : wrapped['updatedAt'] as int?;
  }
}

final cacheServiceProvider = FutureProvider<CacheService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return CacheService(prefs);
});
