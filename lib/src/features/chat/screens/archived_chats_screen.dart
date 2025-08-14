import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/openwebui_client.dart';
import '../widgets/shimmers.dart';

class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});
  static const routePath = '/app/archived';
  static const routeName = 'archived';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Chats'),
        // Back button will show automatically when pushed
        automaticallyImplyLeading: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref
            .read(openWebUIClientProvider.future)
            .then((c) => c.listArchivedChats()),
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: 8,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder:
                  (context, i) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: ShimmerLine(height: 14),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: ShimmerLine(height: 10, width: 120),
                      ),
                    ),
                  ),
            );
          }
          final chats = snap.data!;
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 40),
                  SizedBox(height: 8),
                  Text('No archived chats'),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final chat = chats[i];
              return ListTile(
                title: Text(chat['title'] as String? ?? 'Untitled'),
                subtitle: Text((chat['id'] as String?) ?? ''),
                onTap: () => context.go('/app/chat/room?chatId=${chat['id']}'),
                trailing: PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) async {
                    final client = await ref.read(
                      openWebUIClientProvider.future,
                    );
                    if (value == 'unarchive') {
                      await client.archiveChat(chat['id'] as String);
                      if (context.mounted) {
                        context.go(ArchivedChatsScreen.routePath);
                      }
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text('Delete chat?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                      );
                      if (ok == true) {
                        await client.deleteChat(chat['id'] as String);
                        if (context.mounted) {
                          context.go(ArchivedChatsScreen.routePath);
                        }
                      }
                    }
                  },
                  itemBuilder:
                      (ctx) => const [
                        PopupMenuItem(
                          value: 'unarchive',
                          child: Text('Unarchive'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
