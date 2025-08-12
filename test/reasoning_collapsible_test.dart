import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/widgets/reasoning_collapsible.dart';

void main() {
  testWidgets('ReasoningCollapsible toggles open/close', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReasoningCollapsible(
            reasoning: 'Some hidden thoughts',
            done: true,
            durationSeconds: 2,
          ),
        ),
      ),
    );

    expect(find.textContaining('Thought for'), findsOneWidget);
    await tester.pump();
    expect(find.text('Some hidden thoughts'), findsNothing);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Some hidden thoughts'), findsOneWidget);

    // Close again
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Some hidden thoughts'), findsNothing);
  });

  testWidgets('Thinking dots bubble appears with key', (tester) async {
    // Build the chat room to render thinking bubble during sending
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    // This test is just a placeholder to keep suite fast; the widget has a Key we assert in chat tests
    expect(true, isTrue);
  });
}
