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
    if (base == null || base.isEmpty) {
      if (mounted) context.go(BaseUrlScreen.routePath);
      return;
    }

    final token = await client.token;
    if (token == null || token.isEmpty) {
      // Attempt silent reauth like the web client
      final ok = await client.trySilentReauth();
      if (ok) {
        if (mounted) context.go(ChatRoomScreen.routePath);
      } else {
        if (mounted) context.go(LoginScreen.routePath);
      }
      return;
    }

    try {
      await client.getSessionUser();
      if (mounted) context.go(ChatRoomScreen.routePath);
    } catch (_) {
      if (mounted) context.go(LoginScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
