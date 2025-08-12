import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/widgets/chat_list_drawer.dart';

void main() {
  testWidgets('Drawer list renders shimmer items when loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(drawer: ChatListDrawer(), body: SizedBox()),
      ),
    );
    // open drawer
    final state = tester.state<ScaffoldState>(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();
    // Expect placeholder shimmer lines (ListTiles with ShimmerLine title)
    expect(find.byType(ListTile), findsWidgets);
  });
}
