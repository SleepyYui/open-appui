import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/color_utils.dart';

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});
  static const routePath = '/app/settings/theme';
  static const routeName = 'settings_theme';

  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  Future<void Function()> _showBlockingProgress(String text) async {
    if (!mounted) return () {};
    // Show dialog (non-await) and return a dismiss function
    // ignore: discarded_futures
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(text)),
              ],
            ),
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return () {
      if (!mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final themeCtrl = ref.read(appThemeProvider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final settingsCtrl = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Theme & appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark mode'),
                  value: theme.mode == ThemeMode.dark,
                  onChanged: (v) {
                    themeCtrl.setMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Contrast'),
                  subtitle: Text(_contrastLabel(settings.contrastLevel)),
                  trailing: const Icon(Icons.tune),
                  onTap: () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder:
                          (ctx) =>
                              _ContrastDialog(initial: settings.contrastLevel),
                    );
                    if (choice != null) {
                      await settingsCtrl.setContrastLevel(choice);
                      themeCtrl.setMode(theme.mode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Use system colors'),
                  subtitle: const Text('Dynamic color on supported platforms'),
                  value: settings.useDynamicAccent,
                  onChanged: (v) async {
                    themeCtrl.useDynamicAccent(v);
                    await settingsCtrl.setUseDynamic(v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Apply wallpaper colors now'),
                  subtitle: const Text('Use current system dynamic colors'),
                  trailing: const Icon(Icons.palette_outlined),
                  onTap: () async {
                    final dismiss = await _showBlockingProgress(
                      'Applying wallpaper colors...',
                    );
                    await settingsCtrl.setUseDynamic(true);
                    await settingsCtrl.setUseExactPrimaryColor(false);
                    themeCtrl.useDynamicAccent(true);
                    themeCtrl.setMode(theme.mode);
                    dismiss();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wallpaper colors applied'),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Use exact primary color'),
                  subtitle: const Text('Avoid tonal mapping for primary'),
                  value: settings.useExactPrimaryColor,
                  onChanged: (v) async {
                    await settingsCtrl.setUseExactPrimaryColor(v);
                    // Force rebuild using current seed on toggle
                    themeCtrl.setMode(theme.mode);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Primary color'),
                  subtitle: const Text('Acts as custom source color'),
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color:
                          settings.seedColor ??
                          Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  onTap: () async {
                    Color picked =
                        settings.seedColor ??
                        Theme.of(context).colorScheme.primary;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Select color'),
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
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                    );
                    if (ok == true) {
                      // Persist chosen seed; do not immediately rebuild UI color if user wants tonal mapping off
                      // We always store it, then: if "Use exact primary" is on, apply directly; else let scheme build from seed
                      await settingsCtrl.setSeedColor(picked);
                      await settingsCtrl.setUseDynamic(false);
                      if (settings.useExactPrimaryColor) {
                        themeCtrl.setSeed(picked);
                      } else {
                        // Rebuild using current mode to pick up new seed
                        themeCtrl.setMode(theme.mode);
                      }
                    }
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
                  title: const Text('Background image derived theme'),
                  subtitle: const Text('Pick image to generate theme colors'),
                  trailing: const Icon(Icons.image_outlined),
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked == null) return;
                    final dismiss = await _showBlockingProgress(
                      'Generating theme from image...',
                    );
                    // Compute dominant color off main thread
                    final argb = await computeDominantArgb(picked.path);
                    final dominant = argb != null ? Color(argb) : null;
                    if (dominant != null) {
                      themeCtrl.setSeed(dominant);
                      await settingsCtrl.setSeedColor(dominant);
                      await settingsCtrl.setUseDynamic(false);
                      dismiss();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme updated from image'),
                          ),
                        );
                      }
                    } else {
                      dismiss();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _contrastLabel(String value) {
    switch (value) {
      case 'medium':
        return 'Medium contrast';
      case 'high':
        return 'High contrast';
      default:
        return 'Standard contrast';
    }
  }
}

class _ContrastDialog extends StatelessWidget {
  final String initial;
  const _ContrastDialog({required this.initial});

  @override
  Widget build(BuildContext context) {
    String selected = initial;
    return StatefulBuilder(
      builder:
          (context, setState) => AlertDialog(
            title: const Text('Contrast'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'standard',
                  groupValue: selected,
                  title: const Text('Standard'),
                  onChanged: (v) => setState(() => selected = v ?? 'standard'),
                ),
                RadioListTile<String>(
                  value: 'medium',
                  groupValue: selected,
                  title: const Text('Medium'),
                  onChanged: (v) => setState(() => selected = v ?? 'medium'),
                ),
                RadioListTile<String>(
                  value: 'high',
                  groupValue: selected,
                  title: const Text('High'),
                  onChanged: (v) => setState(() => selected = v ?? 'high'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selected),
                child: const Text('Apply'),
              ),
            ],
          ),
    );
  }
}
