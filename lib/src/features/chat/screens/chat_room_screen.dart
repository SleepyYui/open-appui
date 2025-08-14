import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/openwebui_client.dart';
import '../widgets/chat_list_drawer.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/reasoning_collapsible.dart';
import '../widgets/shimmers.dart';
import '../data/chat_repository.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/settings/app_settings.dart';

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
  final Map<int, _ReasoningMeta> _reasoningByIndex = {};
  bool _sending = false;
  final _input = TextEditingController();
  String? _chatId;
  final ScrollController _scroll = ScrollController();
  // Cache model icons to prevent re-decoding/reloading on every rebuild/stream chunk
  final Map<String, ImageProvider?> _modelIconCache = {};
  String? _assistantPendingId;
  String? _lastUserMsgId;
  bool _assistantStarted = false;

  bool _isThinking = false;
  bool _loadingChat = false;

  ImageProvider? _modelLogo(String? modelId) {
    if (modelId == null) return null;
    if (_modelIconCache.containsKey(modelId)) return _modelIconCache[modelId];
    final m = _models.firstWhere(
      (e) => (e['id'] as String?) == modelId,
      orElse: () => const {},
    );
    final url = (m['info']?['meta']?['profile_image_url'] as String?) ?? '';
    ImageProvider? img;
    if (url.startsWith('http')) {
      img = NetworkImage(url);
    } else if (url.startsWith('data:image')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        img = MemoryImage(base64Decode(base64Str));
      } catch (_) {
        img = null;
      }
    }
    _modelIconCache[modelId] = img;
    return img;
  }

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _loadingChat = widget.chatId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ChatRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      setState(() {
        _chatId = widget.chatId;
        _messages = [];
        _loadingChat = widget.chatId != null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_chatId != null) {
      setState(() => _loadingChat = true);
    }
    // Prime session cache to avoid repeated /auth calls on initial build
    unawaited(ref.read(sessionUserProvider.future));
    final client = await ref.read(openWebUIClientProvider.future);
    // Persist last opened chat id for optional reopening on app launch
    try {
      final settings = ref.read(appSettingsProvider);
      if (settings.reopenLastChatOnLaunch && _chatId != null) {
        await ref
            .read(appSettingsProviderWithPrefs.future)
            .then((c) => c.setLastOpenedChatId(_chatId));
      }
    } catch (_) {}
    final modelsFuture = client.listModels();
    final Future<Map<String, dynamic>?> chatFuture =
        _chatId != null
            ? client.getChatById(_chatId!)
            : Future<Map<String, dynamic>?>.value(null);

    // Await chat first so UI stops showing message shimmer as soon as messages are ready
    final chat = await chatFuture;
    if (chat != null) {
      final historyMap =
          (chat['chat']?['history']?['messages'] ?? {}) as Map<String, dynamic>;
      final currentId = chat['chat']?['history']?['currentId'] as String?;

      List<Map<String, dynamic>> chain = [];
      if (historyMap.isNotEmpty &&
          currentId != null &&
          historyMap[currentId] != null) {
        // Reconstruct chain from root -> current by following parentId links backwards
        String? cursor = currentId;
        while (cursor != null && historyMap[cursor] != null) {
          final node = Map<String, dynamic>.from(historyMap[cursor] as Map);
          chain.add(node);
          cursor = node['parentId'] as String?;
        }
        chain = chain.reversed.toList();
      } else {
        // Fallback: sort by timestamp
        chain =
            historyMap.values
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
              ..sort(
                (a, b) => ((a['timestamp'] ?? 0) as int).compareTo(
                  (b['timestamp'] ?? 0) as int,
                ),
              );
      }

      setState(() {
        _messages =
            chain.map((node) {
              final role = node['role'] as String? ?? 'user';
              final content = node['content'] as String? ?? '';
              final modelId = node['model'] as String?;
              final modelName = node['modelName'] as String?;
              return _Message(
                role: role,
                content: content,
                modelId: role == 'assistant' ? modelId : null,
                modelName: role == 'assistant' ? (modelName ?? modelId) : null,
              );
            }).toList();
      });
    }
    if (mounted && _chatId != null) setState(() => _loadingChat = false);

    // Apply models once available (does not affect message shimmer)
    final models = await modelsFuture;
    if (mounted) {
      setState(() {
        _models = models;
        _selectedModelId =
            models.isNotEmpty ? models.first['id'] as String : null;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _selectedModelId == null) return;
    setState(() {
      _sending = true;
      _assistantStarted = false;
      _isThinking = true;
    });
    final client = await ref.read(openWebUIClientProvider.future);

    // Ensure chat exists and mirror WebUI message/linking flow
    // Generate fresh message ids for this turn
    final now = DateTime.now();
    final modelId = _selectedModelId!;
    final userMsgId = const Uuid().v4();
    final assistantMsgId = const Uuid().v4();
    final tsSec = (now.millisecondsSinceEpoch / 1000).floor();

    if (_chatId == null) {
      // Create new chat seeded with the first user message
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
              'timestamp': tsSec,
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
            'timestamp': tsSec,
            'models': [modelId],
          },
        ],
        'tags': [],
        'timestamp': now.millisecondsSinceEpoch,
      };
      final created = await client.createChat(chat: payloadChat);
      _chatId = created['id'] as String? ?? (created['chat']?['id'] as String?);

      // Pre-create assistant stub linked to user message
      try {
        final modelObj = _models.firstWhere(
          (m) => m['id'] == modelId,
          orElse: () => const {},
        );
        final modelName = (modelObj['name'] as String?) ?? modelId;
        if (_chatId != null) {
          await client.updateChat(
            id: _chatId!,
            chat: {
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
                    'timestamp': tsSec,
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
                    'timestamp': tsSec,
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
                  'timestamp': tsSec,
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
                  'timestamp': tsSec,
                },
              ],
              'params': {},
              'files': [],
            },
          );
        }
      } catch (_) {}
    }
    // Track ids for this turn regardless of new/existing chat
    _assistantPendingId = assistantMsgId;
    _lastUserMsgId = userMsgId;

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
              final think =
                  (delta is Map)
                      ? (delta['reasoning_content'] as String? ??
                          (delta['reasoning'] as String? ??
                              (delta['thinking'] as String? ?? '')))
                      : '';
              if (content.isNotEmpty) {
                if (!_assistantStarted) {
                  setState(() {
                    _assistantStarted = true;
                    _isThinking = false;
                  });
                }
                setState(() {
                  if (_messages.isNotEmpty &&
                      _messages.last.role == 'assistant') {
                    final last = _messages.last;
                    _messages[_messages.length - 1] = _Message(
                      role: 'assistant',
                      content: last.content + content,
                      modelId: last.modelId ?? _selectedModelId,
                      modelName:
                          last.modelName ??
                          _models.firstWhere(
                                (m) => m['id'] == _selectedModelId,
                                orElse: () => const {},
                              )['name']
                              as String?,
                    );
                  } else {
                    final modelObj = _models.firstWhere(
                      (m) => m['id'] == _selectedModelId,
                      orElse: () => const {},
                    );
                    _messages = List.of(_messages)..add(
                      _Message(
                        role: 'assistant',
                        content: content,
                        modelId: _selectedModelId,
                        modelName:
                            (modelObj['name'] as String?) ?? _selectedModelId,
                      ),
                    );
                  }
                  // Attach/accumulate reasoning for this assistant index
                  if (think.isNotEmpty) {
                    final aiIndex = _messages.length - 1;
                    final prev = _reasoningByIndex[aiIndex];
                    _reasoningByIndex[aiIndex] = _ReasoningMeta(
                      text: (prev?.text ?? '') + think,
                      done: prev?.done ?? false,
                      durationSeconds: prev?.durationSeconds,
                    );
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
        // Build minimal chain using actual ids for this turn
        final chain = <Map<String, dynamic>>[
          {
            'id': _lastUserMsgId,
            'role': 'user',
            'content': _messages.firstWhere((m) => m.role == 'user').content,
            'timestamp': nowTs,
          },
          {
            'id': _assistantPendingId,
            'role': 'assistant',
            'content':
                _messages
                    .where((m) => m.role == 'assistant')
                    .map((m) => m.content)
                    .join(),
            'timestamp': nowTs,
          },
        ];

        // Attach model item and session id like WebUI
        Map<String, dynamic>? modelItem;
        try {
          modelItem = _models.firstWhere((m) => m['id'] == _selectedModelId);
        } catch (_) {
          modelItem =
              _selectedModelId == null ? null : {'id': _selectedModelId};
        }
        String? sessionId;
        try {
          final sess = await client.getSessionUser();
          sessionId = sess['socket_id'] as String?;
        } catch (_) {}

        final completedRes = await client.postChatCompleted({
          'model': _selectedModelId,
          'messages': chain,
          if (modelItem != null) 'model_item': modelItem,
          'chat_id': _chatId,
          // Backend expects key to exist; send empty string if unknown
          'session_id': sessionId ?? '',
          'id': _assistantPendingId,
        });

        // If server responded with message updates, merge into existing history (avoid wiping fields)
        if (completedRes.isNotEmpty && completedRes['messages'] is List) {
          try {
            final existing = await client.getChatById(_chatId!);
            final chatMap = Map<String, dynamic>.from(existing['chat'] as Map);
            final historyMessages = Map<String, dynamic>.from(
              (chatMap['history']?['messages'] as Map?) ?? {},
            );
            final serverMessages =
                (completedRes['messages'] as List)
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList();

            for (final m in serverMessages) {
              final id = m['id'] as String?;
              if (id == null) continue;
              final prev = Map<String, dynamic>.from(
                (historyMessages[id] as Map?)?.cast<String, dynamic>() ?? {},
              );
              historyMessages[id] = {...prev, ...m};
            }

            final flat =
                historyMessages.values
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .where((m) => m['role'] != null)
                    .toList()
                  ..sort(
                    (a, b) => ((a['timestamp'] ?? 0) as int).compareTo(
                      (b['timestamp'] ?? 0) as int,
                    ),
                  );

            await client.updateChat(
              id: _chatId!,
              chat: {
                'models': [
                  if ((_selectedModelId ?? '').isNotEmpty) _selectedModelId,
                ],
                'history': {
                  'messages': historyMessages,
                  'currentId': _assistantPendingId,
                },
                'messages': flat,
                'params': chatMap['params'] ?? {},
                'files': chatMap['files'] ?? [],
              },
            );
          } catch (_) {}
        }

        // Persist final assistant message content back to chat history
        if (_chatId != null &&
            _assistantPendingId != null &&
            _lastUserMsgId != null) {
          final modelId = _selectedModelId ?? '';
          final modelObj = _models.firstWhere(
            (m) => m['id'] == modelId,
            orElse: () => const {},
          );
          final modelName = (modelObj['name'] as String?) ?? modelId;
          final assistantContent =
              _messages
                  .where((m) => m.role == 'assistant')
                  .map((m) => m.content)
                  .join();
          final ts = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
          // Update using authoritative history + messages created from history
          final existing = await client.getChatById(_chatId!);
          final chatMap = Map<String, dynamic>.from(existing['chat'] as Map);

          final historyMessages = Map<String, dynamic>.from(
            (chatMap['history']?['messages'] as Map?) ?? {},
          );
          // Ensure user message present and parent/children links
          historyMessages[_lastUserMsgId!] = {
            'id': _lastUserMsgId,
            'parentId': historyMessages[_lastUserMsgId!]?['parentId'],
            'childrenIds': [_assistantPendingId],
            'role': 'user',
            'content': _messages.firstWhere((m) => m.role == 'user').content,
            'timestamp': ts,
            'models': [if (modelId.isNotEmpty) modelId],
          };
          historyMessages[_assistantPendingId!] = {
            'parentId': _lastUserMsgId,
            'id': _assistantPendingId,
            'childrenIds': [],
            'role': 'assistant',
            'content': assistantContent,
            'model': modelId,
            'modelName': modelName,
            'modelIdx': 0,
            'timestamp': ts,
            'done': true,
          };

          // Convert history to flat messages (as WebUI does)
          final flatMessages = <Map<String, dynamic>>[];
          // naive: sort by timestamp
          historyMessages.values
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
            ..sort(
              (a, b) => ((a['timestamp'] ?? 0) as int).compareTo(
                (b['timestamp'] ?? 0) as int,
              ),
            )
            ..forEach(flatMessages.add);

          await client.updateChat(
            id: _chatId!,
            chat: {
              'models': [if (modelId.isNotEmpty) modelId],
              'history': {
                'messages': historyMessages,
                'currentId': _assistantPendingId,
              },
              'messages': flatMessages,
              'params': chatMap['params'] ?? {},
              'files': chatMap['files'] ?? [],
            },
          );
          // assistant message id resolved; no further action needed here
        }
      } catch (_) {}

      // Try auto-generate title for new/untitled chats
      try {
        await _maybeGenerateTitle();
      } catch (_) {}
      // Ensure chats drawer refreshes (especially after new title)
      if (mounted) {
        ref.invalidate(chatsProvider);
        try {
          if (_chatId != null) {
            await ref
                .read(appSettingsProvider.notifier)
                .setLastOpenedChatId(_chatId);
          }
        } catch (_) {}
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _isThinking = false;
        });
      }
    }
  }

  Future<void> _maybeGenerateTitle() async {
    if (_chatId == null) return;
    if ((_selectedModelId ?? '').isEmpty) return;
    final client = await ref.read(openWebUIClientProvider.future);
    // Fetch current chat to check title and messages
    final existing = await client.getChatById(_chatId!);
    final chatMap = Map<String, dynamic>.from(existing['chat'] as Map);
    final currentTitle = (chatMap['title'] as String?)?.trim() ?? '';
    // Only generate if title is missing or default
    if (currentTitle.isNotEmpty &&
        currentTitle.toLowerCase() != 'untitled' &&
        currentTitle.toLowerCase() != 'new chat') {
      return;
    }
    // Build messages payload from local state as role/content pairs
    final messages =
        _messages.map((m) => {'role': m.role, 'content': m.content}).toList();
    if (messages.isEmpty) return;
    final generated = await client.generateTitle(
      model: _selectedModelId!,
      messages: messages,
      chatId: _chatId,
    );
    if (generated == null || generated.trim().isEmpty) return;
    final newTitle = generated.trim();
    if (newTitle != currentTitle) {
      await client.renameChat(id: _chatId!, title: newTitle);
      // Refresh drawer list
      if (mounted) {
        ref.invalidate(chatsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Always show menu to keep drawer accessible when switching between chats
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Open menu',
              ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              _models.isEmpty
                  ? const _ModelSelectorPlaceholder()
                  : _ModelSelector(
                    key: const ValueKey('modelSelector'),
                    models: _models,
                    selectedId: _selectedModelId,
                    iconCache: _modelIconCache,
                    onChanged: (id) => setState(() => _selectedModelId = id),
                  ),
        ),
        centerTitle: true,
        bottom:
            _loadingChat
                ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
                : null,
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add),
            onPressed: () async {
              // Do not create a server chat until the first user message is sent
              // Reset local state and navigate to route without chatId
              if (context.mounted) {
                try {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setLastOpenedChatId(null);
                } catch (_) {}
                context.go(ChatRoomScreen.routePath);
              }
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                itemBuilder: (ctx) {
                  final items = <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: 'settings',
                      child: _PopupRow(icon: Icons.settings, label: 'Settings'),
                    ),
                    const PopupMenuItem(
                      value: 'archived',
                      child: _PopupRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Archived Chats',
                      ),
                    ),
                  ];
                  items.addAll(const [
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'signout',
                      child: _PopupRow(icon: Icons.logout, label: 'Sign Out'),
                    ),
                  ]);
                  return items;
                },
                onSelected: (v) async {
                  if (v == 'signout') {
                    final client = await ref.read(
                      openWebUIClientProvider.future,
                    );
                    await client.signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((_) => true);
                    }
                  } else if (v == 'settings') {
                    if (context.mounted) context.push('/app/settings');
                  } else if (v == 'archived') {
                    if (context.mounted) context.push('/app/archived');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: null,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: imageProvider,
                          backgroundColor:
                              imageProvider == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5)
                                  : null,
                          child:
                              imageProvider == null
                                  ? const Icon(Icons.person_outline, size: 18)
                                  : null,
                        ),
                      ),
                    ),
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
                _loadingChat
                    ? ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: 8,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder:
                          (context, i) => const ShimmerLine(height: 12),
                    )
                    : _messages.isEmpty
                    ? const _WelcomePlaceholder()
                    : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_isThinking ? 1 : 0),
                      itemBuilder: (context, idx) {
                        if (_isThinking && idx == _messages.length) {
                          return const _ThinkingBubble();
                        }
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
                                borderRadius: BorderRadius.circular(16),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 7,
                                        backgroundImage: _modelLogo(m.modelId),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        child:
                                            _modelLogo(m.modelId) == null
                                                ? const Icon(
                                                  Icons.smart_toy_outlined,
                                                  size: 10,
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (m.modelName ??
                                            m.modelId ??
                                            'Assistant'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_reasoningByIndex[idx]?.text
                                      case final r?) ...[
                                    const SizedBox(height: 6),
                                    ReasoningCollapsible(
                                      reasoning: r,
                                      done:
                                          _reasoningByIndex[idx]?.done ?? false,
                                      durationSeconds:
                                          _reasoningByIndex[idx]
                                              ?.durationSeconds,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  MarkdownBody(data: m.content),
                                ],
                              ),
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
  final String? modelId;
  final String? modelName;
  const _Message({
    required this.role,
    required this.content,
    this.modelId,
    this.modelName,
  });
}

class _ReasoningMeta {
  final String text;
  final bool done;
  final int? durationSeconds;
  const _ReasoningMeta({
    required this.text,
    this.done = false,
    this.durationSeconds,
  });
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('thinkingBubble'),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(controller: _controller, delay: 0.0),
            const SizedBox(width: 6),
            _Dot(controller: _controller, delay: 0.15),
            const SizedBox(width: 6),
            _Dot(controller: _controller, delay: 0.30),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.controller, required this.delay});
  final AnimationController controller;
  final double delay;
  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, math.min(1, delay + 0.7), curve: Curves.easeInOut),
    );
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(curved),
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0).animate(curved),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _WelcomePlaceholder extends ConsumerWidget {
  const _WelcomePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref
          .read(openWebUIClientProvider.future)
          .then((c) => c.getSessionUser()),
      builder: (context, snap) {
        final name = (snap.data?['name'] as String?)?.trim();
        final displayName = (name == null || name.isEmpty) ? 'there' : name;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome, $displayName',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'What is it today?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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

class _ModelSelectorPlaceholder extends StatelessWidget {
  const _ModelSelectorPlaceholder();
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
    final highlight = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          key: const Key('modelSelectorPlaceholder'),
          height: 28,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Presence dot removed; now shown in Admin Panel

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    super.key,
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
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
