import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/openwebui_client.dart';
import '../../../core/cache/cache_service.dart';

class ChatRepository {
  ChatRepository(this._client, this._cache);
  final OpenWebUIClient _client;
  final CacheService _cache;

  Future<List<Map<String, dynamic>>> listChats() async {
    try {
      final fresh = await _client.listChats();
      await _cache.setJson('chats', fresh);
      return fresh;
    } catch (_) {
      final cached = _cache.getData<List<dynamic>>('chats');
      return (cached ?? <dynamic>[]).cast<Map<String, dynamic>>();
    }
  }

  Future<Map<String, dynamic>> renameChat(String id, String title) =>
      _client.renameChat(id: id, title: title);
  Future<Map<String, dynamic>> getChat(String id) => _client.getChatById(id);
  Future<Map<String, dynamic>> createChat(Map<String, dynamic> chat) =>
      _client.createChat(chat: chat);
}

final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final client = await ref.watch(openWebUIClientProvider.future);
  final cache = await ref.watch(cacheServiceProvider.future);
  return ChatRepository(client, cache);
});

// Cache-first chats list provider that can be invalidated to refresh the drawer
final chatsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = await ref.watch(chatRepositoryProvider.future);
  return repo.listChats();
});
