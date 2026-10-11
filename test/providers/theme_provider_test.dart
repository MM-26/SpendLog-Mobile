import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendlog_mobile/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeNotifier & themeProvider persistence', () {
    test('Defaults to light theme when no preference is saved', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, ThemeMode.light);
    });

    test('Loads dark theme synchronously on frame 0 when sharedPreferencesProvider is overridden', () async {
      SharedPreferences.setMockInitialValues({'spendlog_theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Immediately dark mode on first synchronous read — no async gap
      final theme = container.read(themeProvider);
      expect(theme, ThemeMode.dark);
    });

    test('Loads light theme synchronously when pref is light', () async {
      SharedPreferences.setMockInitialValues({'spendlog_theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final theme = container.read(themeProvider);
      expect(theme, ThemeMode.light);
    });

    test('toggleTheme persists new theme to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeProvider), ThemeMode.light);

      // Toggle to dark
      await container.read(themeProvider.notifier).toggleTheme();
      expect(container.read(themeProvider), ThemeMode.dark);
      expect(prefs.getString('spendlog_theme_mode'), 'dark');

      // Toggle back to light
      await container.read(themeProvider.notifier).toggleTheme();
      expect(container.read(themeProvider), ThemeMode.light);
      expect(prefs.getString('spendlog_theme_mode'), 'light');
    });

    test('setTheme persists specified mode to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(themeProvider.notifier).setTheme(ThemeMode.dark);
      expect(container.read(themeProvider), ThemeMode.dark);
      expect(prefs.getString('spendlog_theme_mode'), 'dark');
    });
  });
}
