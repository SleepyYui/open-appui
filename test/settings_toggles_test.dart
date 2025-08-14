import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_appui/src/features/chat/screens/settings_screen.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';
import 'package:open_appui/src/core/api/openwebui_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _FakeClient extends OpenWebUIClient {
  _FakeClient(SharedPreferences prefs)
    : super(prefs, const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getSessionProfile() async => {
    'name': 'Tester',
    'email': 'tester@example.com',
    'profile_image_url': '',
  };
}

void main() {
  testWidgets('Settings toggles update provider state', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith((ref) => settings),
          openWebUIClientProvider.overrideWith(
            (ref) async => _FakeClient(prefs),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    // Wait for profile to load
    await tester.pumpAndSettle();

    // Enter key sends message toggle defaults to true
    expect(settings.state.enterToSend, isTrue);

    // Toggle it off
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Enter key sends message'),
    );
    await tester.pumpAndSettle();
    expect(settings.state.enterToSend, isFalse);

    // Toggle reopen-last-chat on
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Re-open last chat on launch'),
    );
    await tester.pumpAndSettle();
    expect(settings.state.reopenLastChatOnLaunch, isTrue);
  });
}
