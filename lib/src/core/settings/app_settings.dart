import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsModel {
  final bool enterToSend;
  final bool useDynamicAccent;
  final Color? seedColor;
  final bool reopenLastChatOnLaunch;
  final bool autoReauthAfterPasswordChange;
  final String contrastLevel; // 'standard' | 'medium' | 'high'
  final bool useExactPrimaryColor; // override tonal mapping for primary

  const AppSettingsModel({
    required this.enterToSend,
    required this.useDynamicAccent,
    required this.seedColor,
    required this.reopenLastChatOnLaunch,
    required this.autoReauthAfterPasswordChange,
    required this.contrastLevel,
    required this.useExactPrimaryColor,
  });

  AppSettingsModel copyWith({
    bool? enterToSend,
    bool? useDynamicAccent,
    Color? seedColor,
    bool? reopenLastChatOnLaunch,
    bool? autoReauthAfterPasswordChange,
    String? contrastLevel,
    bool? useExactPrimaryColor,
  }) => AppSettingsModel(
    enterToSend: enterToSend ?? this.enterToSend,
    useDynamicAccent: useDynamicAccent ?? this.useDynamicAccent,
    seedColor: seedColor ?? this.seedColor,
    reopenLastChatOnLaunch:
        reopenLastChatOnLaunch ?? this.reopenLastChatOnLaunch,
    autoReauthAfterPasswordChange:
        autoReauthAfterPasswordChange ?? this.autoReauthAfterPasswordChange,
    contrastLevel: contrastLevel ?? this.contrastLevel,
    useExactPrimaryColor: useExactPrimaryColor ?? this.useExactPrimaryColor,
  );
}

class AppSettingsController extends StateNotifier<AppSettingsModel> {
  AppSettingsController(this._prefs)
    : super(
        const AppSettingsModel(
          enterToSend: true,
          useDynamicAccent: false,
          seedColor: null,
          reopenLastChatOnLaunch: false,
          autoReauthAfterPasswordChange: false,
          contrastLevel: 'standard',
          useExactPrimaryColor: false,
        ),
      ) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _kEnterToSend = 'enter_to_send';
  static const _kUseDynamic = 'use_dynamic_accent';
  static const _kSeedColor = 'seed_color';
  static const _kReopenLastChat = 'reopen_last_chat_on_launch';
  static const _kAutoReauthAfterPwd = 'auto_reauth_after_password_change';
  static const _kLastOpenedChatId = 'last_opened_chat_id';
  static const _kContrastLevel = 'contrast_level';
  static const _kUseExactPrimary = 'use_exact_primary_color';

  Future<void> _load() async {
    final enter = _prefs.getBool(_kEnterToSend) ?? true;
    final dyn = _prefs.getBool(_kUseDynamic) ?? false;
    final seed = _prefs.getInt(_kSeedColor);
    final reopen = _prefs.getBool(_kReopenLastChat) ?? false;
    final autoReauth = _prefs.getBool(_kAutoReauthAfterPwd) ?? false;
    final contrast = _prefs.getString(_kContrastLevel) ?? 'standard';
    final exactPrimary = _prefs.getBool(_kUseExactPrimary) ?? false;
    state = state.copyWith(
      enterToSend: enter,
      useDynamicAccent: dyn,
      seedColor: seed != null ? Color(seed) : null,
      reopenLastChatOnLaunch: reopen,
      autoReauthAfterPasswordChange: autoReauth,
      contrastLevel: contrast,
      useExactPrimaryColor: exactPrimary,
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

  Future<void> setReopenLastChatOnLaunch(bool v) async {
    await _prefs.setBool(_kReopenLastChat, v);
    state = state.copyWith(reopenLastChatOnLaunch: v);
  }

  Future<void> setAutoReauthAfterPasswordChange(bool v) async {
    await _prefs.setBool(_kAutoReauthAfterPwd, v);
    state = state.copyWith(autoReauthAfterPasswordChange: v);
  }

  Future<void> setContrastLevel(String level) async {
    final normalized =
        (level == 'medium' || level == 'high') ? level : 'standard';
    await _prefs.setString(_kContrastLevel, normalized);
    state = state.copyWith(contrastLevel: normalized);
  }

  Future<void> setUseExactPrimaryColor(bool v) async {
    await _prefs.setBool(_kUseExactPrimary, v);
    state = state.copyWith(useExactPrimaryColor: v);
  }

  Future<void> setLastOpenedChatId(String? id) async {
    if (id == null || id.isEmpty) {
      await _prefs.remove(_kLastOpenedChatId);
    } else {
      await _prefs.setString(_kLastOpenedChatId, id);
    }
  }

  Future<String?> getLastOpenedChatId() async {
    return _prefs.getString(_kLastOpenedChatId);
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
