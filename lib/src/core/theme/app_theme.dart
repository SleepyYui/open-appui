import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/app_settings.dart';

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
  AppThemeController() : super(_initialTheme());

  static AppThemeModel _initialTheme() {
    return AppThemeModel(
      light: _buildLightTheme(),
      dark: _buildDarkTheme(),
      mode: ThemeMode.dark,
    );
  }

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
      // watch settings to react to theme-related settings
      ref.listen<AppSettingsModel>(appSettingsProvider, (_, next) {
        _contrastLevel = next.contrastLevel;
        _preferExactPrimary = next.useExactPrimaryColor;
      });
      return AppThemeController();
    });

String _contrastLevel = 'standard';
bool _preferExactPrimary = false;

ThemeData _buildLightTheme() {
  final scheme =
      _useDynamicAccent && _dynamicLight != null
          ? _dynamicLight!
          : ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: Brightness.light,
          );
  final adjusted = _applyContrast(scheme, Brightness.light);
  final base = ThemeData(useMaterial3: true, colorScheme: adjusted);

  return base.copyWith(
    colorScheme: adjusted,
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
  final adjusted = _applyContrast(scheme, Brightness.dark);
  final base = ThemeData(useMaterial3: true, colorScheme: adjusted);

  return base.copyWith(
    colorScheme: adjusted,
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
      backgroundColor: adjusted.surface,
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
        foregroundColor: adjusted.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: adjusted.outlineVariant, width: 1.2),
      ),
    ),
    cardTheme: CardTheme(
      color: adjusted.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: adjusted.outlineVariant, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: adjusted.surface),
  );
}

ColorScheme _applyContrast(ColorScheme input, Brightness b) {
  // If user wants exact primary, re-map roles to align closer with source
  ColorScheme scheme =
      _preferExactPrimary
          ? input.copyWith(
            primary: _seedColor,
            primaryContainer: _mix(input.primaryContainer, _seedColor, 0.5),
            onPrimary: _bestOn(_seedColor, b),
          )
          : input;

  // Brand tint: slightly blend primary into background/surfaces
  final double surfaceTint =
      _contrastLevel == 'high'
          ? 0.08
          : (_contrastLevel == 'medium' ? 0.06 : 0.04);
  scheme = scheme.copyWith(
    surface: _mix(scheme.surface, _seedColor, surfaceTint),
    background: _mix(scheme.background, _seedColor, surfaceTint),
  );

  if (_contrastLevel == 'standard') return scheme;
  // Medium: slightly increase contrasts
  if (_contrastLevel == 'medium') {
    return scheme.copyWith(
      outlineVariant: _tint(scheme.outlineVariant, b, amount: 0.12),
      onSurface: _tint(scheme.onSurface, b, amount: 0.10),
      surfaceContainerHighest: _tint(
        scheme.surfaceContainerHighest,
        b,
        amount: 0.10,
      ),
    );
  }
  // High: stronger contrast adjustments
  return scheme.copyWith(
    outlineVariant: _tint(scheme.outlineVariant, b, amount: 0.22),
    onSurface: _tint(scheme.onSurface, b, amount: 0.20),
    surfaceContainerHighest: _tint(
      scheme.surfaceContainerHighest,
      b,
      amount: 0.18,
    ),
  );
}

Color _tint(Color c, Brightness b, {double amount = 0.1}) {
  final hsl = HSLColor.fromColor(c);
  if (b == Brightness.dark) {
    return hsl.withLightness((hsl.lightness + amount).clamp(0, 1)).toColor();
  }
  return hsl.withLightness((hsl.lightness - amount).clamp(0, 1)).toColor();
}

Color _mix(Color a, Color b, double t) {
  return Color.fromARGB(
    (a.alpha + (b.alpha - a.alpha) * t).round(),
    (a.red + (b.red - a.red) * t).round(),
    (a.green + (b.green - a.green) * t).round(),
    (a.blue + (b.blue - a.blue) * t).round(),
  );
}

Color _bestOn(Color base, Brightness b) {
  // Choose white or black based on luminance and brightness context
  final l = base.computeLuminance();
  if (b == Brightness.dark) {
    return l > 0.4 ? Colors.black : Colors.white;
  }
  return l > 0.6 ? Colors.black : Colors.white;
}
