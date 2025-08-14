import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/openwebui_client.dart';
import '../screens/chat_room_screen.dart';
import '../../onboarding/screens/login_screen.dart';
import '../../../core/settings/app_settings.dart';
import 'theme_settings_screen.dart';
import 'webview_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  static const routePath = '/app/settings';
  static const routeName = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final settingsCtrl = ref.read(appSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref
            .read(openWebUIClientProvider.future)
            .then((c) => c.getSessionProfile()),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final name = data['name'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final image = data['profile_image_url'] as String? ?? '';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      image.isNotEmpty ? NetworkImage(image) : null,
                  child:
                      image.isEmpty ? const Icon(Icons.person_outline) : null,
                ),
                title: Text(name.isEmpty ? 'User' : name),
                subtitle: Text(email),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    final controller = TextEditingController(text: name);
                    final urlCtrl = TextEditingController(text: image);
                    final updated = await showDialog<Map<String, String>?>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Edit profile'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: controller,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: urlCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Profile image URL',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed:
                                    () => Navigator.of(ctx).pop({
                                      'name': controller.text,
                                      'url': urlCtrl.text,
                                    }),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                    );
                    if (updated != null) {
                      final client = await ref.read(
                        openWebUIClientProvider.future,
                      );
                      await client.updateProfile(
                        name: updated['name'] ?? name,
                        profileImageUrl: updated['url'] ?? image,
                      );
                      if (context.mounted) context.go(SettingsScreen.routePath);
                    }
                  },
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 12),
              // Move admin panel access into Settings for admins/debug
              FutureBuilder<Map<String, dynamic>>(
                future: ref
                    .read(openWebUIClientProvider.future)
                    .then((c) => c.getSessionUser()),
                builder: (context, sessionSnap) {
                  final role =
                      (sessionSnap.data?['role'] as String?)?.toLowerCase();
                  final isAdmin = role == 'admin';
                  return (isAdmin || kDebugMode)
                      ? Card(
                        child: ListTile(
                          title: const Text('Admin Panel'),
                          subtitle: const Text('Server info and tools'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/app/admin'),
                        ),
                      )
                      : const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Theme & appearance'),
                      subtitle: const Text('Colors, contrast, backgrounds'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(ThemeSettingsScreen.routePath),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Change WebUI URL'),
                      subtitle: const Text('Switch the Open WebUI server'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final base = await ref
                            .read(openWebUIClientProvider.future)
                            .then((c) => c.baseUrl ?? '');
                        final ctrl = TextEditingController(text: base);
                        final saved = await showDialog<String?>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Open WebUI URL'),
                                content: TextField(
                                  controller: ctrl,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Base URL (e.g. https://host:port)',
                                  ),
                                  keyboardType: TextInputType.url,
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(
                                          ctx,
                                        ).pop(ctrl.text.trim()),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                        );
                        if (saved != null) {
                          final client = await ref.read(
                            openWebUIClientProvider.future,
                          );
                          await client.setBaseUrl(saved);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Base URL updated')),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Enter key sends message'),
                      value: settings.enterToSend,
                      onChanged: (v) async {
                        await settingsCtrl.setEnterToSend(v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Re-open last chat on launch'),
                      value: settings.reopenLastChatOnLaunch,
                      onChanged: (v) async {
                        await settingsCtrl.setReopenLastChatOnLaunch(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Account settings'),
                      subtitle: const Text('Profile, API keys, password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => context.push(AccountSettingsScreen.routePath),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Open WebUI Settings'),
                      subtitle: const Text('Manage settings in WebUI'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => context.push(WebViewScreen.routePath),
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

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});
  static const routePath = '/app/settings/account';
  static const routeName = 'settings_account';

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _autoReauth = false;
  String? _sessionEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.read(appSettingsProvider);
      setState(() => _autoReauth = settings.autoReauthAfterPasswordChange);
      try {
        final client = await ref.read(openWebUIClientProvider.future);
        final session = await client.getSessionUser();
        setState(() => _sessionEmail = session['email'] as String?);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const ListTile(
            title: Text('Change password'),
            subtitle: Text('Update your account password'),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _currentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto sign-in after password change'),
                    subtitle: const Text(
                      'If enabled, the app will sign in again automatically if the password change succeeds, using the new password.',
                    ),
                    value: _autoReauth,
                    onChanged: (v) async {
                      setState(() => _autoReauth = v);
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setAutoReauthAfterPasswordChange(v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _autoReauth
                          ? 'After changing your password, the app will attempt to sign in again automatically using your new password. If re-authentication fails, you will be signed out and must log in manually.'
                          : 'After changing your password, you will be signed out and must log in with your new password.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () async {
                        final client = await ref.read(
                          openWebUIClientProvider.future,
                        );
                        try {
                          final ok = await client.updatePassword(
                            currentPassword: _currentCtrl.text,
                            newPassword: _newCtrl.text,
                          );
                          if (!ok) throw Exception('Password update failed');
                          if (!mounted) return;
                          if (_autoReauth && (_sessionEmail ?? '').isNotEmpty) {
                            try {
                              await client.signIn(
                                email: _sessionEmail!,
                                password: _newCtrl.text,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password updated. You have been signed in with your new password.',
                                    ),
                                  ),
                                );
                                context.go(ChatRoomScreen.routePath);
                              }
                            } catch (e) {
                              await client.signOut();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Password updated. Please sign in again. ($e)',
                                    ),
                                  ),
                                );
                                context.go(LoginScreen.routePath);
                              }
                            }
                          } else {
                            await client.signOut();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated. You have been signed out.',
                                  ),
                                ),
                              );
                              context.go(LoginScreen.routePath);
                            }
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Update password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
