// lib/config/theme/theme_provider.dart
//
// Reemplaza a lib/theme_provider.dart (booleano
// `isDarkMode`, clave SharedPreferences 'isDarkMode'). Ahora persiste un
// [ThemeMode] completo bajo la clave 'theme_mode', habilitando la tercera
// opción "Sistema" — MaterialApp delega en MediaQuery.platformBrightness
// sin que la app tenga que espiar el brillo de la plataforma a mano.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    if (mode != _themeMode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}
