import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/settings/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OpenAppUI()));
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

    // Apply settings after build to avoid provider modification during build
    ref.watch(appSettingsProviderWithPrefs).whenData((ctrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final t = ref.read(appThemeProvider.notifier);
        if (_lastSeed != ctrl.state.seedColor && ctrl.state.seedColor != null) {
          t.setSeed(ctrl.state.seedColor!);
          _lastSeed = ctrl.state.seedColor;
        }
        if (_lastDynamic != ctrl.state.useDynamicAccent) {
          t.useDynamicAccent(ctrl.state.useDynamicAccent);
          _lastDynamic = ctrl.state.useDynamicAccent;
        }
      });
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
