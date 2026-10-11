import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemePrefKey = 'spendlog_theme_mode';

/// Optional provider for pre-initialized [SharedPreferences].
/// Overridden at app start in [main] so the initial theme is available
/// synchronously on frame zero — no async gap, no flash.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Manages the app's theme mode (light / dark) with [SharedPreferences]
/// persistence. The preference is written on every toggle and read
/// synchronously at startup via [sharedPreferencesProvider].
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final saved = prefs.getString(_kThemePrefKey);
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'light') return ThemeMode.light;
    }
    return ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    await _persist(newMode);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _persist(mode);
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs =
          ref.read(sharedPreferencesProvider) ??
          await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemePrefKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('ThemeNotifier: failed to persist theme: $e');
    }
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
