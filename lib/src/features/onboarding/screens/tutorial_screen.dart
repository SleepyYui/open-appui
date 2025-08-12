import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/screens/chat_room_screen.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static const routePath = '/onboarding/tutorial';
  static const routeName = 'tutorial';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick tour')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to OpenWebUI',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              '• Switch models via the top bar\n'
              '• Browse and rename your chats\n'
              '• Send messages and get responses from your selected model',
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => context.go(ChatRoomScreen.routePath),
              icon: const Icon(Icons.check),
              label: const Text('Start chatting'),
            ),
          ],
        ),
      ),
    );
  }
}
