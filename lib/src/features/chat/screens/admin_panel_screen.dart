import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/openwebui_client.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});
  static const routePath = '/app/admin';
  static const routeName = 'admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        automaticallyImplyLeading: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref
            .read(openWebUIClientProvider.future)
            .then((c) => c.getServerConfig()),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final config = snap.data ?? const {};
          final debug = kDebugMode;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Info',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _KV(
                        'Version',
                        (config['version'] ?? 'unknown').toString(),
                      ),
                      _KV('Models', (config['models']?.length ?? 0).toString()),
                      _KV('Auth', (config['auth'] ?? {}).toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: ref
                            .read(openWebUIClientProvider.future)
                            .then((c) => c.getActiveUsersCount()),
                        builder: (context, snap) {
                          final count = snap.data;
                          if (count == null) {
                            return const LinearProgressIndicator(minHeight: 2);
                          }
                          return Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 10,
                                color: Color(0xFF22C55E),
                              ),
                              const SizedBox(width: 8),
                              Text('Active users: $count'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Verbose logging'),
                      value: debug,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Refresh model list'),
                      onTap: () async {
                        final client = await ref.read(
                          openWebUIClientProvider.future,
                        );
                        await client.listModels(refresh: true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Models refreshed')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              k,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(v, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
