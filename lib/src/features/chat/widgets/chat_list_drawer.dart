import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/screens/chat_room_screen.dart';
import '../data/chat_repository.dart';
import 'shimmers.dart';

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
                loading:
                    () => ListView.separated(
                      itemCount: 10,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder:
                          (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              title: const ShimmerLine(height: 14),
                            ),
                          ),
                    ),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (chats) {
                  if (chats.isEmpty) {
                    // No cache and loading finished -> empty placeholder list
                    return ListView.separated(
                      itemCount: 8,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder:
                          (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              title: const ShimmerLine(height: 14),
                            ),
                          ),
                    );
                  }
                  // Sort by updated_at desc and group into date sections
                  final now = DateTime.now();
                  final sorted = List<Map<String, dynamic>>.from(chats)..sort(
                    (a, b) => (b['updated_at'] as int).compareTo(
                      a['updated_at'] as int,
                    ),
                  );
                  final Map<String, List<Map<String, dynamic>>> sections = {};
                  String labelFor(int tsSeconds) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      tsSeconds * 1000,
                    );
                    final local = dt;
                    final startOfToday = DateTime(now.year, now.month, now.day);
                    final startOfYesterday = startOfToday.subtract(
                      const Duration(days: 1),
                    );
                    if (local.isAfter(startOfToday)) return 'Today';
                    if (local.isAfter(startOfYesterday)) return 'Yesterday';
                    if (now.difference(local).inDays <= 7) return 'Last Week';
                    if (now.difference(local).inDays <= 30) return 'Last Month';
                    if (local.year == now.year) {
                      // Month name + year for current year older than 30d
                      return _formatMonthYear(local);
                    }
                    return local.year.toString();
                  }

                  for (final c in sorted) {
                    final label = labelFor(c['updated_at'] as int);
                    sections.putIfAbsent(label, () => []).add(c);
                  }

                  final headers = sections.keys.toList();
                  return ListView.builder(
                    itemCount: headers.length,
                    itemBuilder: (context, i) {
                      final header = headers[i];
                      final items = sections[header]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                            child: Text(
                              header,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          ...items.map(
                            (chat) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(
                                  vertical: -2,
                                  horizontal: -2,
                                ),
                                title: Text(
                                  (chat['title'] as String? ?? 'Untitled'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(context).maybePop();
                                  context.go(
                                    '${ChatRoomScreen.routePath}?chatId=${chat['id']}',
                                  );
                                },
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (value) async {
                                    final repo = await ref.read(
                                      chatRepositoryProvider.future,
                                    );
                                    if (value == 'pin') {
                                      await repo.pinChat(chat['id'] as String);
                                      ref.invalidate(chatsProvider);
                                    } else if (value == 'rename') {
                                      final newTitle =
                                          await showDialog<String?>(
                                            context: context,
                                            builder:
                                                (ctx) => _RenameDialog(
                                                  initial:
                                                      chat['title']
                                                          as String? ??
                                                      '',
                                                ),
                                          );
                                      if (newTitle != null &&
                                          newTitle.trim().isNotEmpty) {
                                        await repo.renameChat(
                                          chat['id'] as String,
                                          newTitle.trim(),
                                        );
                                        ref.invalidate(chatsProvider);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    } else if (value == 'clone') {
                                      await repo.cloneChat(
                                        chat['id'] as String,
                                      );
                                      ref.invalidate(chatsProvider);
                                    } else if (value == 'archive') {
                                      await repo.archiveChat(
                                        chat['id'] as String,
                                      );
                                      ref.invalidate(chatsProvider);
                                    } else if (value == 'share') {
                                      await repo.shareChat(
                                        chat['id'] as String,
                                      );
                                    } else if (value == 'download') {
                                      // not implemented
                                    } else if (value == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: const Text('Delete chat?'),
                                              content: const Text(
                                                'This cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        ctx,
                                                      ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        ctx,
                                                      ).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (ok == true) {
                                        await repo.deleteChat(
                                          chat['id'] as String,
                                        );
                                        ref.invalidate(chatsProvider);
                                      }
                                    }
                                  },
                                  itemBuilder:
                                      (ctx) => const [
                                        PopupMenuItem(
                                          value: 'pin',
                                          child: _PopupRow(
                                            icon: Icons.bookmark_border,
                                            label: 'Pin',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: _PopupRow(
                                            icon: Icons.edit_outlined,
                                            label: 'Rename',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'clone',
                                          child: _PopupRow(
                                            icon: Icons.copy_all_outlined,
                                            label: 'Clone',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'archive',
                                          child: _PopupRow(
                                            icon: Icons.archive_outlined,
                                            label: 'Archive',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'share',
                                          child: _PopupRow(
                                            icon: Icons.share_outlined,
                                            label: 'Share',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'download',
                                          child: _PopupRow(
                                            icon: Icons.download_outlined,
                                            label: 'Download',
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: _PopupRow(
                                            icon: Icons.delete_outline,
                                            label: 'Delete',
                                          ),
                                        ),
                                      ],
                                ),
                              ),
                            ),
                          ),
                        ],
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

String _formatMonthYear(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

class _PopupRow extends StatelessWidget {
  const _PopupRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
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
