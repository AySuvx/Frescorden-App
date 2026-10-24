// Persiste el banner elegido por el usuario para el encabezado del menú
// (DrawerHeader en InicioScreen) bajo la clave 'user_banner' en
// SharedPreferences — mismo patrón que ThemeProvider. Se guarda el nombre
// de archivo (ej. "Perritos.jpg"), no un índice: así la elección sobrevive
// aunque la galería cambie de orden o tamaño en una versión futura.
//
// `null` = sin banner elegido, se usa el degradado de marca por defecto
// (ver InicioScreen._buildDrawer) en vez de una foto.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Galería curada: nombres de archivo dentro de assets/banners-usuario/.
/// Se declaran acá (no se listan dinámicamente desde el sistema de
/// archivos — Flutter no permite eso en runtime) para que agregar/quitar
/// una foto sea un cambio de una sola línea, en este archivo y en
/// pubspec.yaml si la carpeta cambia.
const List<String> kUserBannerOptions = [
  'Perritos.jpg',
  'Gato.jpg',
  'Oveja.jpg',
  'Frutas.jpg',
  'Verduras.jpg',
];

class UserBannerProvider with ChangeNotifier {
  static const _prefsKey = 'user_banner';
  static const _assetFolder = 'assets/banners-usuario/';

  String? _selectedBanner;

  /// Ruta de asset lista para `Image.asset`, o `null` si no hay banner
  /// elegido (degradado por defecto).
  String? get selectedBannerAsset =>
      _selectedBanner == null ? null : '$_assetFolder$_selectedBanner';

  /// Nombre de archivo tal cual se guarda (para marcar la opción elegida
  /// en la galería), o `null`.
  String? get selectedBannerName => _selectedBanner;

  UserBannerProvider() {
    _load();
  }

  Future<void> setBanner(String? fileName) async {
    if (_selectedBanner == fileName) return;
    _selectedBanner = fileName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (fileName == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, fileName);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null || !kUserBannerOptions.contains(stored)) return;
    _selectedBanner = stored;
    notifyListeners();
  }
}
