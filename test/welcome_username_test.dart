import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/screens/chat_room_screen.dart';
import 'test_utils.dart';

void main() {
  testWidgets('Welcome placeholder shows greeting text', (tester) async {
    final app = await withFakeClient(
      const MaterialApp(home: Scaffold(body: ChatRoomScreen())),
    );
    await tester.pumpWidget(app);
    // Initial empty state uses welcome placeholder headline
    expect(find.textContaining('Welcome,'), findsOneWidget);
  });
}
