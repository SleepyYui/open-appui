import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_appui/src/core/theme/app_theme.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';
import 'package:open_appui/src/features/chat/screens/theme_settings_screen.dart';

void main() {
  testWidgets('Contrast modal changes contrast and tints surfaces', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: ProviderScope(
          child: MaterialApp(
            theme: _testTheme(ref: null),
            home: const ThemeSettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open contrast dialog via the tile that has a tune icon
    final contrastTileFinder = find.byWidgetPredicate((w) {
      if (w is ListTile) {
        final title = w.title;
        final trailing = w.trailing;
        return title is Text &&
            title.data == 'Contrast' &&
            trailing is Icon &&
            trailing.icon == Icons.tune;
      }
      return false;
    });
    await tester.tap(contrastTileFinder.first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Pick Medium and apply
    await tester.tap(find.text('Medium'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(settings.state.contrastLevel, 'medium');
  });

  testWidgets('Use exact primary applies selected seed color', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: ProviderScope(
          child: MaterialApp(
            theme: _testTheme(ref: null),
            home: const ThemeSettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Toggle exact primary on
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Use exact primary color'),
    );
    await tester.pumpAndSettle();
    expect(settings.state.useExactPrimaryColor, isTrue);
  });

  testWidgets('Dark mode switch toggles app theme mode', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(home: const ThemeSettingsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(ThemeSettingsScreen));
    final container = ProviderScope.containerOf(ctx);

    // Initially dark
    expect(container.read(appThemeProvider).mode, ThemeMode.dark);

    // Toggle dark mode off
    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark mode'));
    await tester.pumpAndSettle();
    expect(container.read(appThemeProvider).mode, ThemeMode.light);
  });
}

ThemeData _testTheme({WidgetRef? ref}) {
  final controller = AppThemeController();
  final model = controller.state;
  return model.light.copyWith();
}
