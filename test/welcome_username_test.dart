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
    // On first frame, a shimmer placeholder is shown while loading
    expect(find.byKey(const Key('modelSelectorPlaceholder')), findsOneWidget);
    // Allow async _load to complete
    await tester.pump(const Duration(milliseconds: 50));
    // Then welcome placeholder should appear
    expect(find.textContaining('Welcome,'), findsOneWidget);
  });
}
