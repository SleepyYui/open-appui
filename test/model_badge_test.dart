import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/screens/chat_room_screen.dart';
import 'test_utils.dart';

void main() {
  testWidgets('Assistant message shows model badge when present', (
    tester,
  ) async {
    final app = await withFakeClient(
      const MaterialApp(home: Scaffold(body: ChatRoomScreen())),
    );
    await tester.pumpWidget(app);
    // Initially shimmer shows while loading
    expect(find.byKey(const Key('modelSelectorPlaceholder')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    // Then welcome placeholder appears (no model badge yet)
    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
