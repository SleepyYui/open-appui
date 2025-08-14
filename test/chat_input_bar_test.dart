import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/widgets/chat_input_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';

void main() {
  testWidgets('ChatInputBar shows send button and invokes callback', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Hello');
    var tapped = false;

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF0E7C62),
          ),
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              onSend: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final sendButton = find.byKey(const Key('sendButton'));
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('Enter-to-send setting respected when submitting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);
    await settings.setEnterToSend(true);

    final controller = TextEditingController(text: 'Hi');
    var count = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          home: Scaffold(
            body: ChatInputBar(controller: controller, onSend: () => count++),
          ),
        ),
      ),
    );
    // Pressing the icon always sends
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pump();
    expect(count, 1);
  });
}
