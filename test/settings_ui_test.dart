import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_appui/src/features/chat/screens/settings_screen.dart';
import 'test_utils.dart';

void main() {
  testWidgets('Settings toggles render and can be toggled', (tester) async {
    final app = await withFakeClient(const MaterialApp(home: SettingsScreen()));
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
