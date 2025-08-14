import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/onboarding/screens/base_url_screen.dart';
import 'features/onboarding/screens/login_screen.dart';
import 'features/onboarding/screens/tutorial_screen.dart';
import 'features/chat/screens/chat_shell.dart';
import 'features/chat/screens/chat_room_screen.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/chat/screens/settings_screen.dart';
import 'features/chat/screens/archived_chats_screen.dart';
import 'features/chat/screens/admin_panel_screen.dart';
import 'features/chat/screens/theme_settings_screen.dart';
import 'features/chat/screens/webview_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashScreen.routePath,
    routes: [
      GoRoute(
        path: SplashScreen.routePath,
        name: SplashScreen.routeName,
        builder: (context, state) => const SplashScreen(),
      ),
      // Backwards-compat/alias: redirect /app/chat -> /app/chat/room
      GoRoute(
        path: ChatShell.routePath,
        redirect: (context, state) => ChatRoomScreen.routePath,
      ),
      GoRoute(
        path: BaseUrlScreen.routePath,
        name: BaseUrlScreen.routeName,
        builder: (context, state) => const BaseUrlScreen(),
      ),
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: TutorialScreen.routePath,
        name: TutorialScreen.routeName,
        builder: (context, state) => const TutorialScreen(),
      ),
      // Shell with nested routes for main app
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                ChatShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ChatRoomScreen.routePath,
                name: ChatRoomScreen.routeName,
                builder: (context, state) {
                  final chatId = state.uri.queryParameters['chatId'];
                  return ChatRoomScreen(chatId: chatId);
                },
              ),
              GoRoute(
                path: SettingsScreen.routePath,
                name: SettingsScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: SettingsScreen()),
              ),
              GoRoute(
                path: AccountSettingsScreen.routePath,
                name: AccountSettingsScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: AccountSettingsScreen()),
              ),
              GoRoute(
                path: BaseUrlScreen.settingsRoutePath,
                name: BaseUrlScreen.settingsRouteName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: BaseUrlScreen()),
              ),
              GoRoute(
                path: ThemeSettingsScreen.routePath,
                name: ThemeSettingsScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: ThemeSettingsScreen()),
              ),
              GoRoute(
                path: WebViewScreen.routePath,
                name: WebViewScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: WebViewScreen()),
              ),
              GoRoute(
                path: ArchivedChatsScreen.routePath,
                name: ArchivedChatsScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: ArchivedChatsScreen()),
              ),
              GoRoute(
                path: AdminPanelScreen.routePath,
                name: AdminPanelScreen.routeName,
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(child: AdminPanelScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
