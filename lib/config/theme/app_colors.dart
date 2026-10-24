// Paleta de marca: tokens de color literales, fuente única de verdad para
// AppTheme. Ninguna pantalla debe declarar estos hex directamente — se
// consumen vía `Theme.of(context).colorScheme` (roles derivados) o, para
// los dos casos de fondo que el rol `surface` no cubre con precisión
// (fondo de pantalla y tarjeta en modo oscuro), vía estas constantes.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Verde Esmeralda — color de marca, semilla del ColorScheme (rol
  /// `primary`). Tanto en claro como en oscuro, Material3 deriva de acá los
  /// tonos on*/container garantizando el contraste del algoritmo tonal.
  static const Color primary = Color(0xFF2E7D32);

  /// Ámbar — semántica de advertencia (rol `tertiary`: "por vencer",
  /// stock bajo, avisos no bloqueantes).
  static const Color warning = Color(0xFFF57C00);

  /// Coral — semántica de error (rol `error`: vencido, presupuesto
  /// superado, eliminar).
  static const Color error = Color(0xFFD32F2F);

  /// Fondo de pantalla en modo claro.
  static const Color backgroundLight = Color(0xFFF8F9FA);

  /// Fondo de pantalla en modo oscuro (cercano a negro puro: pensado para
  /// pantallas OLED, reduce consumo y evita el "halo" de un negro
  /// verdadero #000000 contra tarjetas).
  static const Color backgroundDark = Color(0xFF121212);

  /// Superficie de tarjeta en modo oscuro. Deliberadamente más clara que
  /// [backgroundDark] (no un color derivado del tema): la diferencia de
  /// luminosidad es la que comunica "elevación" en OLED, en vez de una
  /// sombra que ahí no se percibe.
  static const Color cardDark = Color(0xFF1E1E1E);

  /// Superficie de tarjeta en modo claro. Blanco puro sobre
  /// [backgroundLight]: mismo criterio que arriba, aplicado al modo claro.
  static const Color cardLight = Colors.white;

  /// Colores de acento curados para Ajustes (ver ThemeProvider.setSeedColor):
  /// un selector de color libre no se ofrece a propósito — cada entrada ya
  /// viene probada contra el `contrastLevel` 0.5 de AppTheme en claro y
  /// oscuro, así ningún usuario puede elegir una semilla que rompa el
  /// contraste AA de la app.
  static const List<MapEntry<String, Color>> accentPresets = [
    MapEntry('Esmeralda', primary),
    MapEntry('Azul', Color(0xFF1565C0)),
    MapEntry('Morado', Color(0xFF6A1B9A)),
    MapEntry('Naranja', Color(0xFFE65100)),
    MapEntry('Rosa', Color(0xFFC2185B)),
    MapEntry('Turquesa', Color(0xFF00796B)),
    MapEntry('Índigo', Color(0xFF283593)),
  ];
}
