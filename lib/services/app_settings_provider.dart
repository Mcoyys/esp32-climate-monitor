import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _darkModeKey = 'darkMode';
  static const String _autoThemeKey = 'autoTheme';

  bool _isDarkMode = false;
  bool _useAutomaticTheme = false;

  bool get isDarkMode => _useAutomaticTheme ? _isNight() : _isDarkMode;
  bool get useAutomaticTheme => _useAutomaticTheme;
  ThemeMode get themeMode {
    if (_useAutomaticTheme) {
      return _isNight() ? ThemeMode.dark : ThemeMode.light;
    }
    return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  AppSettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _useAutomaticTheme = prefs.getBool(_autoThemeKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    _useAutomaticTheme = false;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    await prefs.setBool(_autoThemeKey, _useAutomaticTheme);
  }

  Future<void> setUseAutomaticTheme(bool useAuto) async {
    _useAutomaticTheme = useAuto;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoThemeKey, _useAutomaticTheme);
  }

  bool _isNight() {
    final hour = DateTime.now().hour;
    return hour < 7 || hour >= 19;
  }
}
