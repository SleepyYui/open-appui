import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/openwebui_client.dart';
import '../widgets/chat_list_drawer.dart';
import '../widgets/chat_input_bar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, this.chatId});

  static const routePath = '/app/chat/room';
  static const routeName = 'chat_room';

  final String? chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  String? _selectedModelId;
  List<Map<String, dynamic>> _models = const [];
  List<_Message> _messages = [];
  bool _sending = false;
  final _input = TextEditingController();
  String? _chatId;
  final ScrollController _scroll = ScrollController();
  // Cache model icons to prevent re-decoding/reloading on every rebuild/stream chunk
  final Map<String, ImageProvider?> _modelIconCache = {};
  String? _assistantPendingId;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = await ref.read(openWebUIClientProvider.future);
    final models = await client.listModels();
    setState(() {
      _models = models;
      _selectedModelId =
          models.isNotEmpty ? models.first['id'] as String : null;
    });

    if (_chatId != null) {
      final chat = await client.getChatById(_chatId!);
      final history =
          (chat['chat']?['history']?['messages'] ?? {}) as Map<String, dynamic>;
      final ordered =
          history.values.map((e) => e as Map<String, dynamic>).toList()..sort(
            (a, b) => ((a['createdAt'] ?? 0) as int).compareTo(
              (b['createdAt'] ?? 0) as int,
            ),
          );
      setState(() {
        _messages =
            ordered
                .map(
                  (m) => _Message(
                    role: m['role'] as String? ?? 'user',
                    content: m['content'] as String? ?? '',
                  ),
                )
                .toList();
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _selectedModelId == null) return;
    setState(() => _sending = true);
    final client = await ref.read(openWebUIClientProvider.future);

    // Ensure chat exists and mirror WebUI first-message flow.
    // IMPORTANT: Reuse the same chat id across subsequent sends; do not recreate.
    if (_chatId == null) {
      final userMsgId = const Uuid().v4();
      final assistantMsgId = const Uuid().v4();
      final now = DateTime.now();
      final modelId = _selectedModelId!;
      final payloadChat = {
        'id': const Uuid().v4(),
        'title': 'New Chat',
        'models': [modelId],
        'params': {},
        'history': {
          'currentId': userMsgId,
          'messages': {
            userMsgId: {
              'id': userMsgId,
              'parentId': null,
              'childrenIds': [],
              'role': 'user',
              'content': text,
              'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
              'models': [modelId],
            },
          },
        },
        'messages': [
          {
            'id': userMsgId,
            'parentId': null,
            'childrenIds': [],
            'role': 'user',
            'content': text,
            'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
            'models': [modelId],
          },
        ],
        'tags': [],
        'timestamp': now.millisecondsSinceEpoch,
      };

      final created = await client.createChat(chat: payloadChat);
      _chatId = created['id'] as String?;
      // safety: if web returns nested chat.chat.id as authoritative
      _chatId ??= (created['chat']?['id'] as String?);

      // Mirror WebUI: pre-create assistant stub and link to user message, so that
      // the completions stream can reference the assistant id.
      try {
        final modelObj = _models.firstWhere(
          (m) => m['id'] == modelId,
          orElse: () => const {},
        );
        final modelName = (modelObj['name'] as String?) ?? modelId;
        final updatePayload = {
          'models': [modelId],
          'history': {
            'currentId': assistantMsgId,
            'messages': {
              userMsgId: {
                'id': userMsgId,
                'parentId': null,
                'childrenIds': [assistantMsgId],
                'role': 'user',
                'content': text,
                'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
                'models': [modelId],
              },
              assistantMsgId: {
                'parentId': userMsgId,
                'id': assistantMsgId,
                'childrenIds': [],
                'role': 'assistant',
                'content': '',
                'model': modelId,
                'modelName': modelName,
                'modelIdx': 0,
                'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
              },
            },
          },
          'messages': [
            {
              'id': userMsgId,
              'parentId': null,
              'childrenIds': [assistantMsgId],
              'role': 'user',
              'content': text,
              'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
              'models': [modelId],
            },
            {
              'parentId': userMsgId,
              'id': assistantMsgId,
              'childrenIds': [],
              'role': 'assistant',
              'content': '',
              'model': modelId,
              'modelName': modelName,
              'modelIdx': 0,
              'timestamp': (now.millisecondsSinceEpoch / 1000).floor(),
            },
          ],
          'params': {},
          'files': [],
        };
        if (_chatId != null) {
          await client.updateChat(id: _chatId!, chat: updatePayload);
          _assistantPendingId = assistantMsgId;
        }
      } catch (_) {}
    }

    // Append user message locally
    setState(() {
      _messages = List.of(_messages)
        ..add(_Message(role: 'user', content: text));
      _input.clear();
    });

    try {
      final payload = {
        'model': _selectedModelId,
        'messages': [
          ..._messages.map((m) => {'role': m.role, 'content': m.content}),
        ],
        'chat_id': _chatId,
        'stream': true,
        if (_assistantPendingId != null) 'id': _assistantPendingId,
      };

      final streamed = await client.streamChatCompletion(payload: payload);
      String buffer = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer += chunk;
        // try parse NDJSON or SSE-like data lines
        for (final line in buffer.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final contentLine =
              trimmed.startsWith('data:')
                  ? trimmed.substring(5).trim()
                  : trimmed;
          try {
            final data = jsonDecode(contentLine) as Map<String, dynamic>;
            final choices = data['choices'];
            if (choices is List && choices.isNotEmpty) {
              final delta =
                  (choices.first as Map)['delta'] ??
                  (choices.first as Map)['message'];
              final content =
                  (delta is Map) ? (delta['content'] as String? ?? '') : '';
              if (content.isNotEmpty) {
                setState(() {
                  if (_messages.isNotEmpty &&
                      _messages.last.role == 'assistant') {
                    _messages[_messages.length - 1] = _Message(
                      role: 'assistant',
                      content: _messages.last.content + content,
                    );
                  } else {
                    _messages = List.of(_messages)
                      ..add(_Message(role: 'assistant', content: content));
                  }
                });
                // keep view pinned to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
              }
            }
          } catch (_) {
            // ignore non-json lines
          }
        }
        // keep last partial line in buffer
        final lastNewline = buffer.lastIndexOf('\n');
        if (lastNewline >= 0) buffer = buffer.substring(lastNewline + 1);
      }
      // After stream completes, call chat/completed & update chat with final messages
      try {
        final nowTs = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
        final msgs = <Map<String, dynamic>>[];
        for (final m in _messages) {
          msgs.add({
            'id': const Uuid().v4(),
            'role': m.role,
            'content': m.content,
            'timestamp': nowTs,
          });
        }
        await client.postChatCompleted({
          'model': _selectedModelId,
          'messages': msgs,
          'model_item':
              _selectedModelId == null ? null : {'id': _selectedModelId},
          'chat_id': _chatId,
          'id': const Uuid().v4(),
        });
      } catch (_) {}
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: _ModelSelector(
          models: _models,
          selectedId: _selectedModelId,
          iconCache: _modelIconCache,
          onChanged: (id) => setState(() => _selectedModelId = id),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final model = _selectedModelId;
              if (model == null) return;
              final client = await ref.read(openWebUIClientProvider.future);
              final created = await client.createChat(
                chat: {
                  'id': const Uuid().v4(),
                  'title': 'New Chat',
                  'models': [model],
                  'params': {},
                  'history': {'currentId': null, 'messages': {}},
                  'messages': [],
                  'tags': [],
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              );
              setState(() {
                _chatId = created['id'] as String?;
                _messages = [];
              });
            },
          ),
          const SizedBox(width: 4),
          FutureBuilder<Map<String, dynamic>>(
            future: ref
                .read(openWebUIClientProvider.future)
                .then((c) => c.getSessionUser()),
            builder: (context, snapshot) {
              final url = snapshot.data?['profile_image_url'] as String?;
              final imageProvider =
                  (url != null && url.isNotEmpty) ? NetworkImage(url) : null;
              return PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 40),
                itemBuilder:
                    (ctx) => [
                      const PopupMenuItem(
                        value: 'settings',
                        child: _PopupRow(
                          icon: Icons.settings,
                          label: 'Settings',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archived',
                        child: _PopupRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Archived Chats',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'playground',
                        child: _PopupRow(
                          icon: Icons.smart_toy_outlined,
                          label: 'Playground',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'admin',
                        child: _PopupRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Admin Panel',
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'signout',
                        child: _PopupRow(icon: Icons.logout, label: 'Sign Out'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        enabled: false,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 10,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Users: 1',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                onSelected: (v) async {
                  if (v == 'signout') {
                    final client = await ref.read(
                      openWebUIClientProvider.future,
                    );
                    await client.signOut();
                    if (context.mounted)
                      Navigator.of(context).popUntil((_) => true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: imageProvider,
                    child:
                        imageProvider == null
                            ? const Icon(Icons.person_outline, size: 18)
                            : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const ChatListDrawer(),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: 6,
                      itemBuilder:
                          (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Align(
                              alignment:
                                  i.isEven
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                              child: Container(
                                height: 16,
                                width:
                                    MediaQuery.of(context).size.width *
                                    (0.4 + (i % 3) * 0.15),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                    )
                    : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, idx) {
                        final m = _messages[idx];
                        final isUser = m.role == 'user';
                        if (isUser) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(m.content),
                            ),
                          );
                        } else {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: MarkdownBody(data: m.content),
                            ),
                          );
                        }
                      },
                    ),
          ),
          SafeArea(
            child: ChatInputBar(
              controller: _input,
              onSend: _send,
              isSending: _sending,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String content;
  const _Message({required this.role, required this.content});
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

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.models,
    required this.selectedId,
    required this.iconCache,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> models;
  final String? selectedId;
  final Map<String, ImageProvider?> iconCache;
  final ValueChanged<String> onChanged;

  ImageProvider? _iconFromUrlCached(String id, String url) {
    if (iconCache.containsKey(id)) return iconCache[id];
    ImageProvider? image;
    if (url.startsWith('http')) {
      image = NetworkImage(url);
    } else if (url.startsWith('data:image')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        image = MemoryImage(base64Decode(base64Str));
      } catch (_) {
        image = null;
      }
    }
    iconCache[id] = image;
    return image;
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    final selected = models.firstWhere(
      (m) => m['id'] == selectedId,
      orElse: () => models.isNotEmpty ? models.first : {},
    );
    final title =
        (selected['name'] as String?) ?? (selected['id'] as String? ?? '');
    final iconUrl =
        (selected['info']?['meta']?['profile_image_url'] as String?) ?? '';
    final img =
        iconUrl.isNotEmpty
            ? _iconFromUrlCached(selected['id'] as String? ?? title, iconUrl)
            : null;

    final screenWidth = MediaQuery.of(context).size.width;
    // Leave room for leading menu + two actions (new chat + avatar)
    final maxWidth = math.max(
      100.0,
      math.min(screenWidth * 0.6, screenWidth - 160.0),
    );
    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder:
              (ctx) => SafeArea(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: models.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final m = models[i];
                    final id = m['id'] as String;
                    final name = (m['name'] as String?) ?? id;
                    final iconUrl =
                        (m['info']?['meta']?['profile_image_url'] as String?) ??
                        '';
                    final mi =
                        iconUrl.isNotEmpty
                            ? _iconFromUrlCached(id, iconUrl)
                            : null;
                    final active = id == selectedId;
                    return ListTile(
                      leading:
                          mi != null
                              ? CircleAvatar(
                                radius: 14,
                                backgroundImage: mi,
                                backgroundColor: Colors.transparent,
                              )
                              : const Icon(Icons.smart_toy_outlined),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      trailing: active ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.of(ctx).pop(id),
                    );
                  },
                ),
              ),
        );
        if (selected != null) onChanged(selected);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (img != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image(image: img, width: 16, height: 16),
                ),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
