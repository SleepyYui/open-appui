import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_router.dart';
import 'src/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OpenAppUI()));
}

class OpenAppUI extends ConsumerWidget {
  const OpenAppUI({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OpenAppUI',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.mode,
      routerConfig: router,
    );
  }
}
