import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsModel {
  final bool enterToSend;
  final bool useDynamicAccent;
  final Color? seedColor;

  const AppSettingsModel({
    required this.enterToSend,
    required this.useDynamicAccent,
    required this.seedColor,
  });

  AppSettingsModel copyWith({
    bool? enterToSend,
    bool? useDynamicAccent,
    Color? seedColor,
  }) => AppSettingsModel(
    enterToSend: enterToSend ?? this.enterToSend,
    useDynamicAccent: useDynamicAccent ?? this.useDynamicAccent,
    seedColor: seedColor ?? this.seedColor,
  );
}

class AppSettingsController extends StateNotifier<AppSettingsModel> {
  AppSettingsController(this._prefs)
    : super(
        const AppSettingsModel(
          enterToSend: true,
          useDynamicAccent: false,
          seedColor: null,
        ),
      ) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _kEnterToSend = 'enter_to_send';
  static const _kUseDynamic = 'use_dynamic_accent';
  static const _kSeedColor = 'seed_color';

  Future<void> _load() async {
    final enter = _prefs.getBool(_kEnterToSend) ?? true;
    final dyn = _prefs.getBool(_kUseDynamic) ?? false;
    final seed = _prefs.getInt(_kSeedColor);
    state = state.copyWith(
      enterToSend: enter,
      useDynamicAccent: dyn,
      seedColor: seed != null ? Color(seed) : null,
    );
  }

  Future<void> setEnterToSend(bool v) async {
    await _prefs.setBool(_kEnterToSend, v);
    state = state.copyWith(enterToSend: v);
  }

  Future<void> setUseDynamic(bool v) async {
    await _prefs.setBool(_kUseDynamic, v);
    state = state.copyWith(useDynamicAccent: v);
  }

  Future<void> setSeedColor(Color? c) async {
    if (c == null) {
      await _prefs.remove(_kSeedColor);
    } else {
      await _prefs.setInt(_kSeedColor, c.value);
    }
    state = state.copyWith(seedColor: c);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsModel>((ref) {
      throw UnimplementedError(
        'appSettingsProvider must be overridden with prefs',
      );
    });

final appSettingsProviderWithPrefs = FutureProvider<AppSettingsController>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final ctrl = AppSettingsController(prefs);
  return ctrl;
});
