import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/screens/chat_room_screen.dart';
import '../data/chat_repository.dart';

class ChatListDrawer extends ConsumerWidget {
  const ChatListDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Consumer(
            builder: (context, ref, _) {
              final asyncChats = ref.watch(chatsProvider);
              return asyncChats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (chats) {
                  if (chats.isEmpty) {
                    return const Center(child: Text('No chats yet'));
                  }
                  return ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final chat = chats[idx];
                      return ListTile(
                        title: Text(chat['title'] as String? ?? 'Untitled'),
                        subtitle: Text((chat['id'] as String).substring(0, 6)),
                        onTap:
                            () => context.go(
                              '${ChatRoomScreen.routePath}?chatId=${chat['id']}',
                            ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final repo = await ref.read(
                              chatRepositoryProvider.future,
                            );
                            final newTitle = await showDialog<String?>(
                              context: context,
                              builder:
                                  (ctx) => _RenameDialog(
                                    initial: chat['title'] as String? ?? '',
                                  ),
                            );
                            if (newTitle != null &&
                                newTitle.trim().isNotEmpty) {
                              await repo.renameChat(
                                chat['id'] as String,
                                newTitle.trim(),
                              );
                              ref.invalidate(chatsProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
