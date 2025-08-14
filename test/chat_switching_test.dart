import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/widgets/chat_list_drawer.dart';
import 'test_utils.dart';

void main() {
  testWidgets('Drawer list renders shimmer items when loading', (tester) async {
    final app = await withFakeClient(
      const MaterialApp(
        home: Scaffold(drawer: ChatListDrawer(), body: SizedBox()),
      ),
    );
    await tester.pumpWidget(app);
    // open drawer
    final state = tester.state<ScaffoldState>(find.byType(Scaffold));
    state.openDrawer();
    // Drawer may have animations; pump a few frames
    await tester.pump(const Duration(milliseconds: 100));
    // Expect placeholder shimmer lines (ListTiles with ShimmerLine title)
    expect(find.byType(ListTile), findsWidgets);
  });
}
