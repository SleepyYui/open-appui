import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final appSettingsController = AppSettingsController(prefs);
  runApp(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith((ref) => appSettingsController),
      ],
      child: const OpenAppUI(),
    ),
  );
}

class OpenAppUI extends ConsumerStatefulWidget {
  const OpenAppUI({super.key});

  @override
  ConsumerState<OpenAppUI> createState() => _OpenAppUIState();
}

class _OpenAppUIState extends ConsumerState<OpenAppUI> {
  bool _appliedDynamic = false;
  Color? _lastSeed;
  bool? _lastDynamic;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final router = ref.watch(appRouterProvider);

    final settings = ref.watch(appSettingsProvider);
    // Apply settings after build to avoid provider modification during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = ref.read(appThemeProvider.notifier);
      if (_lastSeed != settings.seedColor && settings.seedColor != null) {
        t.setSeed(settings.seedColor!);
        _lastSeed = settings.seedColor;
      }
      if (_lastDynamic != settings.useDynamicAccent) {
        t.useDynamicAccent(settings.useDynamicAccent);
        _lastDynamic = settings.useDynamicAccent;
      }
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_appliedDynamic) {
            ref
                .read(appThemeProvider.notifier)
                .setDynamicSchemes(light: lightDynamic, dark: darkDynamic);
            _appliedDynamic = true;
            // Set capability flag: any platform that returns dynamic schemes supports it
            final supported = (lightDynamic != null || darkDynamic != null);
            ref.read(supportsDynamicColorProvider.notifier).state = supported;
          }
        });
        return MaterialApp.router(
          title: 'OpenAppUI',
          debugShowCheckedModeBanner: false,
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: theme.mode,
          scrollBehavior: const AppScrollBehavior(),
          routerConfig: router,
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // No glow/stretch indicators
  }
}
