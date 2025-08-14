import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/openwebui_client.dart';
import 'base_url_screen.dart';
import 'login_screen.dart';
import '../../chat/screens/chat_room_screen.dart';
import '../../../core/settings/app_settings.dart';

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
    final settingsCtrl = await ref.read(appSettingsProviderWithPrefs.future);
    final base = client.baseUrl;
    if (base == null || base.isEmpty) {
      if (mounted) context.go(BaseUrlScreen.routePath);
      return;
    }

    final token = await client.token;
    if (token == null || token.isEmpty) {
      if (mounted) context.go(LoginScreen.routePath);
      return;
    }

    try {
      await client.getSessionUser();
      if (mounted) {
        final reopen = settingsCtrl.state.reopenLastChatOnLaunch;
        if (reopen) {
          try {
            final lastId = await settingsCtrl.getLastOpenedChatId();
            if (lastId != null && lastId.isNotEmpty) {
              context.go('${ChatRoomScreen.routePath}?chatId=$lastId');
              return;
            }
            final chats = await client.listChats(page: 1);
            if (chats.isNotEmpty) {
              final sorted = List<Map<String, dynamic>>.from(chats)..sort(
                (a, b) =>
                    (b['updated_at'] as int).compareTo(a['updated_at'] as int),
              );
              final id = sorted.first['id'] as String?;
              if (id != null && id.isNotEmpty) {
                context.go('${ChatRoomScreen.routePath}?chatId=$id');
                return;
              }
            }
          } catch (_) {}
        }
        context.go(ChatRoomScreen.routePath);
      }
    } catch (e) {
      if (mounted) context.go(LoginScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
