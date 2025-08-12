import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatShell extends StatelessWidget {
  const ChatShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const routePath = '/app/chat';
  static const routeName = 'chat_shell';

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: shell);
  }
}
