import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/onboarding/screens/base_url_screen.dart';
import 'features/onboarding/screens/login_screen.dart';
import 'features/onboarding/screens/tutorial_screen.dart';
import 'features/chat/screens/chat_shell.dart';
import 'features/chat/screens/chat_room_screen.dart';
import 'features/onboarding/screens/splash_screen.dart';

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
            ],
          ),
        ],
      ),
    ],
  );
});
