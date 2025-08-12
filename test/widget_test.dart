// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/screens/chat_room_screen.dart';

void main() {
  testWidgets('Model selector shows shimmer placeholder before load', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatRoomScreen())),
    );
    // Initial build shows placeholder until models load
    expect(find.byKey(const Key('modelSelectorPlaceholder')), findsOneWidget);
  });
}
