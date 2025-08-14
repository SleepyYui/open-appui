import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:open_appui/src/core/api/openwebui_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOpenWebUIClient extends OpenWebUIClient {
  FakeOpenWebUIClient._(super.prefs, super.secure);

  static Future<FakeOpenWebUIClient> create() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    return FakeOpenWebUIClient._(prefs, secure);
  }

  @override
  Future<Map<String, dynamic>> getSessionUser() async {
    return {
      'name': 'Tester',
      'email': 'tester@example.com',
      'profile_image_url': '',
    };
  }

  @override
  Future<Map<String, dynamic>> getSessionProfile() async => getSessionUser();

  @override
  Future<List<Map<String, dynamic>>> listModels({bool refresh = false}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> listChats({int? page}) async {
    return [];
  }

  @override
  Future<http.StreamedResponse> streamChatCompletion({
    required Map<String, dynamic> payload,
  }) async {
    final controller = StreamController<List<int>>();
    Future.microtask(() {
      controller.add(utf8.encode('data: [DONE]\n'));
      controller.close();
    });
    return http.StreamedResponse(
      controller.stream,
      200,
      request: http.Request('POST', Uri.parse('http://localhost/')),
    );
  }
}

Future<Widget> withFakeClient(Widget child) async {
  final fake = await FakeOpenWebUIClient.create();
  return ProviderScope(
    overrides: [openWebUIClientProvider.overrideWith((ref) async => fake)],
    child: child,
  );
}
