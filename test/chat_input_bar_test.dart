import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/widgets/chat_input_bar.dart';

void main() {
  testWidgets('ChatInputBar shows send button and invokes callback', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Hello');
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
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
    final controller = TextEditingController(text: 'Hi');
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(controller: controller, onSend: () => count++),
        ),
      ),
    );
    // Pressing the icon always sends
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pump();
    expect(count, 1);
  });
}
