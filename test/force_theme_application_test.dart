import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_appui/src/core/theme/app_theme.dart';
import 'package:open_appui/src/core/settings/app_settings.dart';

void main() {
  testWidgets('Toggling exact primary rebuilds theme immediately', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettingsController(prefs);

    final app = ProviderScope(
      overrides: [appSettingsProvider.overrideWith((ref) => settings)],
      child: const _Harness(),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Initially off
    expect(settings.state.useExactPrimaryColor, isFalse);

    // Flip and expect state change
    settings.setUseExactPrimaryColor(true);
    await tester.pump();
    expect(settings.state.useExactPrimaryColor, isTrue);
  });
}

class _Harness extends ConsumerWidget {
  const _Harness();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    return MaterialApp(
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.mode,
      home: const Scaffold(body: SizedBox()),
    );
  }
}
