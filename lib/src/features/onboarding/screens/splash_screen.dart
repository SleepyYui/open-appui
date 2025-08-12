import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/openwebui_client.dart';
import 'base_url_screen.dart';
import 'login_screen.dart';
import '../../chat/screens/chat_room_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const routePath = '/';
  static const routeName = 'splash';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final client = await ref.read(openWebUIClientProvider.future);
    final base = client.baseUrl;
    // Debug trace for routing decisions (no secrets printed)
    // ignore: avoid_print
    print('[Splash] baseUrl=$base');
    if (base == null || base.isEmpty) {
      if (mounted) context.go(BaseUrlScreen.routePath);
      return;
    }

    final token = await client.token;
    // ignore: avoid_print
    print('[Splash] tokenPresent=${token != null && token.isNotEmpty}');
    if (token == null || token.isEmpty) {
      if (mounted) context.go(LoginScreen.routePath);
      return;
    }

    try {
      // ignore: avoid_print
      print('[Splash] validating session via /auths');
      await client.getSessionUser();
      // ignore: avoid_print
      print('[Splash] session valid');
      if (mounted) context.go(ChatRoomScreen.routePath);
    } catch (e) {
      // ignore: avoid_print
      print('[Splash] session invalid: $e');
      if (mounted) context.go(LoginScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
