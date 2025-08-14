import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_appui/src/features/chat/widgets/chat_input_bar.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';

void main() {
  testWidgets('Enter key sends when enabled', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);
    await settings.setEnterToSend(true);

    var sent = false;
    final controller = TextEditingController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              onSend: () => sent = true,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sent, isTrue);
  });
}
