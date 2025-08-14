import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_appui/src/core/api/openwebui_client.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';

class FakeOpenWebUIClient extends OpenWebUIClient {
  FakeOpenWebUIClient(SharedPreferences prefs)
    : super(prefs, const _NoopSecureStorage());

  Map<String, dynamic> _sessionUser = {
    'email': 'user@example.com',
    'name': 'Test User',
    'profile_image_url': '',
  };
  List<Map<String, dynamic>> _chats = [];

  void setChats(List<Map<String, dynamic>> chats) {
    _chats = chats;
  }

  void setSessionUser(Map<String, dynamic> user) {
    _sessionUser = user;
  }

  @override
  Future<Map<String, dynamic>> getSessionUser() async {
    return _sessionUser;
  }

  @override
  Future<List<Map<String, dynamic>>> listChats({int? page}) async {
    return _chats;
  }

  bool updatedPassword = false;
  @override
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    updatedPassword = true;
    return true;
  }

  bool signedOut = false;
  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  bool signedIn = false;
  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    signedIn = true;
    return {'token': 'fake'};
  }
}

class _NoopSecureStorage extends FlutterSecureStorage {
  const _NoopSecureStorage();
}

ProviderScope buildTestScope({
  required Widget child,
  required OpenWebUIClient client,
  AppSettingsController? settings,
}) {
  final overrides = <Override>[
    openWebUIClientProvider.overrideWith((ref) async => client),
  ];
  if (settings != null) {
    overrides.add(appSettingsProvider.overrideWith((ref) => settings));
  }
  return ProviderScope(overrides: overrides, child: child);
}
