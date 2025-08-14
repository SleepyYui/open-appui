import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});
  static const routePath = '/app/settings/theme';
  static const routeName = 'settings_theme';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                SwitchListTile(
                  title: const Text('Use exact primary color'),
                  subtitle: const Text('Avoid tonal mapping for primary'),
                  value: settings.useExactPrimaryColor,
                  onChanged: (v) async {
                    await settingsCtrl.setUseExactPrimaryColor(v);
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
                      themeCtrl.setSeed(picked);
                      await settingsCtrl.setSeedColor(picked);
                      await settingsCtrl.setUseDynamic(false);
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
                    final file = File(picked.path);
                    final palette = await PaletteGenerator.fromImageProvider(
                      FileImage(file),
                    );
                    final dominant = palette.dominantColor?.color;
                    if (dominant != null) {
                      themeCtrl.setSeed(dominant);
                      await settingsCtrl.setSeedColor(dominant);
                      await settingsCtrl.setUseDynamic(false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme updated from image'),
                          ),
                        );
                      }
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
  const _ContrastDialog({super.key, required this.initial});

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
