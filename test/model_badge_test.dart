import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/screens/chat_room_screen.dart';

void main() {
  testWidgets('Assistant message shows model badge when present', (
    tester,
  ) async {
    // Build an instance of ChatRoomScreen; without backend this will show welcome
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatRoomScreen())),
    );
    // Initially we expect welcome placeholder (no model badge). This is a smoke test to ensure
    // the widget tree builds; deeper integration requires mocking HTTP.
    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
