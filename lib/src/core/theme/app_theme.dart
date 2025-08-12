import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppThemeModel {
  final ThemeData light;
  final ThemeData dark;
  final ThemeMode mode;

  const AppThemeModel({
    required this.light,
    required this.dark,
    required this.mode,
  });

  AppThemeModel copyWith({ThemeData? light, ThemeData? dark, ThemeMode? mode}) {
    return AppThemeModel(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      mode: mode ?? this.mode,
    );
  }
}

class AppThemeController extends StateNotifier<AppThemeModel> {
  AppThemeController()
    : super(
        AppThemeModel(
          light: _buildLightTheme(),
          dark: _buildDarkTheme(),
          mode: ThemeMode.dark,
        ),
      );

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeController, AppThemeModel>((ref) {
      return AppThemeController();
    });

ThemeData _buildLightTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: base.colorScheme.outlineVariant,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: base.colorScheme.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(width: 1.2),
      ),
    ),
    cardTheme: const CardTheme(
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  const black = Color(0xFF000000);
  const surface = Color(0xFF0A0A0A);
  final scheme = const ColorScheme.dark().copyWith(
    primary: const Color(0xFFB69DF8),
    secondary: const Color(0xFF8A80FF),
    background: black,
    surface: surface,
    onBackground: Colors.white,
    onSurface: Colors.white,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: black,
    dialogBackgroundColor: surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outlineVariant, width: 1.2),
      ),
    ),
    cardTheme: CardTheme(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
    ),
  );
}
