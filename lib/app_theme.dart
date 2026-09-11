// lib/app_theme.dart
//
// Tema centralizado de la app (mejora arquitectónica previa al rediseño de
// interfaz): antes, `MaterialApp.theme` solo fijaba `primarySwatch` (API de
// Material 2, no genera un ColorScheme completo) y cada pantalla repetía
// `backgroundColor: Colors.green` a mano en su propio AppBar — cambiar el
// color de marca exigía tocar ~10 archivos. Según la documentación oficial
// de Flutter (flutter.dev, guía de theming Material 3, vigente desde
// Flutter 3.16 con `useMaterial3` en `true` por defecto), el patrón
// recomendado es `ColorScheme.fromSeed(seedColor: ...)` + los `*Theme` de
// componente (AppBarTheme, ElevatedButtonTheme, ...) en un único ThemeData
// — así cada widget hereda el color sin declararlo.
//
// Alcance de este cambio: solo AppBar y ElevatedButton, que son los que
// hoy repiten Colors.green de forma literalmente redundante con el tema.
// Los verdes/rojos/naranjas semánticos (tarjetas de éxito/advertencia,
// badges de stock bajo, etc.) NO se tocan acá — son decisiones de paleta
// que le corresponden al rediseño visual completo, no a esta limpieza.

import 'package:flutter/material.dart';

const _seedColor = Colors.green;

ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
  );
}
