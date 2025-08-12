import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Runtime theme configuration
Color _seedColor = const Color(0xFF0E7C62);
bool _useDynamicAccent = false;
ColorScheme? _dynamicLight;
ColorScheme? _dynamicDark;

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

  void setSeed(Color seed) {
    _seedColor = seed;
    _useDynamicAccent = false;
    state = state.copyWith(light: _buildLightTheme(), dark: _buildDarkTheme());
  }

  void useDynamicAccent(bool enable) {
    _useDynamicAccent = enable;
    state = state.copyWith(light: _buildLightTheme(), dark: _buildDarkTheme());
  }

  void setDynamicSchemes({ColorScheme? light, ColorScheme? dark}) {
    _dynamicLight = light;
    _dynamicDark = dark;
    if (_useDynamicAccent) {
      state = state.copyWith(
        light: _buildLightTheme(),
        dark: _buildDarkTheme(),
      );
    }
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeController, AppThemeModel>((ref) {
      return AppThemeController();
    });

ThemeData _buildLightTheme() {
  final scheme =
      _useDynamicAccent && _dynamicLight != null
          ? _dynamicLight!
          : ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: Brightness.light,
          );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkSparkle.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
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
  final scheme =
      _useDynamicAccent && _dynamicDark != null
          ? _dynamicDark!
          : ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: Brightness.dark,
          );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  const black = Color(0xFF000000);
  const surface = Color(0xFF0A0A0A);

  return base.copyWith(
    colorScheme: scheme.copyWith(background: black, surface: surface),
    scaffoldBackgroundColor: black,
    dialogBackgroundColor: surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkSparkle.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
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
