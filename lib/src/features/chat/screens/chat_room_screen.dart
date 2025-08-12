import 'dart:async';
import 'dart:convert';

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

    // Ensure chat exists and mirror WebUI first-message flow
    if (_chatId == null) {
      final userMsgId = const Uuid().v4();
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
        await client.postChatCompleted({
          'model': _selectedModelId,
          'messages':
              _messages
                  .map((m) => {'role': m.role, 'content': m.content})
                  .toList(),
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
        ],
      ),
      drawer: const ChatListDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                        color: Theme.of(context).colorScheme.primaryContainer,
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

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.models,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> models;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  ImageProvider? _iconFromUrl(String url) {
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = models.firstWhere(
      (m) => m['id'] == selectedId,
      orElse: () => models.isNotEmpty ? models.first : {},
    );
    final title =
        (selected['name'] as String?) ?? (selected['id'] as String? ?? '');
    final iconUrl =
        (selected['info']?['meta']?['profile_image_url'] as String?) ?? '';
    final img = iconUrl.isNotEmpty ? _iconFromUrl(iconUrl) : null;

    final maxWidth = MediaQuery.of(context).size.width * 0.75;
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
                        iconUrl.isNotEmpty ? _iconFromUrl(iconUrl) : null;
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
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            color: Colors.transparent,
          ),
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
