import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/openwebui_client.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/settings/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  static const routePath = '/app/settings';
  static const routeName = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final controller = ref.read(appThemeProvider.notifier);
    final settingsCtrlAsync = ref.watch(appSettingsProviderWithPrefs);
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
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark mode'),
                      value: theme.mode == ThemeMode.dark,
                      onChanged: (v) {
                        controller.setMode(
                          v ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Accent color'),
                      subtitle: const Text('Pick a custom accent color'),
                      trailing: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      onTap: () async {
                        Color picked = Theme.of(context).colorScheme.primary;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Select accent color'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: picked,
                                    onColorChanged: (c) => picked = c,
                                    enableAlpha: false,
                                    displayThumbColor: true,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(true),
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
                        );
                        if (ok == true) {
                          controller.setSeed(picked);
                          final setCtrl = await ref.read(
                            appSettingsProviderWithPrefs.future,
                          );
                          await setCtrl.setSeedColor(picked);
                          await setCtrl.setUseDynamic(false);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Use system dynamic color'),
                      value: settingsCtrlAsync.maybeWhen(
                        data: (c) => c.state.useDynamicAccent,
                        orElse: () => false,
                      ),
                      onChanged: (v) async {
                        controller.useDynamicAccent(v);
                        final setCtrl = await ref.read(
                          appSettingsProviderWithPrefs.future,
                        );
                        await setCtrl.setUseDynamic(v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Enter key sends message'),
                      value: settingsCtrlAsync.maybeWhen(
                        data: (c) => c.state.enterToSend,
                        orElse: () => true,
                      ),
                      onChanged: (v) async {
                        final setCtrl = await ref.read(
                          appSettingsProviderWithPrefs.future,
                        );
                        await setCtrl.setEnterToSend(v);
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
                      title: const Text('Account'),
                      subtitle: const Text('Profile and security settings'),
                    ),
                    ListTile(
                      title: const Text('Change password'),
                      subtitle: const Text('Secure your account'),
                      onTap: () async {
                        final current = TextEditingController();
                        final next = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Change password'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: current,
                                      decoration: const InputDecoration(
                                        labelText: 'Current password',
                                      ),
                                      obscureText: true,
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: next,
                                      decoration: const InputDecoration(
                                        labelText: 'New password',
                                      ),
                                      obscureText: true,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(true),
                                    child: const Text('Update'),
                                  ),
                                ],
                              ),
                        );
                        if (ok == true) {
                          final client = await ref.read(
                            openWebUIClientProvider.future,
                          );
                          await client.updatePassword(
                            currentPassword: current.text,
                            newPassword: next.text,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated')),
                            );
                          }
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
