// Persiste un [ThemeMode] completo bajo la clave 'theme_mode' en
// SharedPreferences, habilitando la opción "Sistema" — MaterialApp delega
// en MediaQuery.platformBrightness sin que la app tenga que espiar el
// brillo de la plataforma a mano.
//
// También persiste el color de acento (seed color de Material3) bajo
// 'seed_color' — ver AppColors.accentPresets para las opciones curadas que
// ofrece Ajustes. Se guarda como el int ARGB (`Color.toARGB32()`), no el
// índice de la lista de presets: así un usuario conserva su color elegido
// aunque la lista de presets cambie de orden o de tamaño en una versión
// futura.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeProvider with ChangeNotifier {
  static const _prefsKey = 'theme_mode';
  static const _seedColorPrefsKey = 'seed_color';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = AppColors.primary;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  ThemeProvider() {
    _loadThemeMode();
    _loadSeedColor();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> setSeedColor(Color color) async {
    if (_seedColor.toARGB32() == color.toARGB32()) return;
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorPrefsKey, color.toARGB32());
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

  Future<void> _loadSeedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_seedColorPrefsKey);
    if (stored == null) return;
    _seedColor = Color(stored);
    notifyListeners();
  }
}
