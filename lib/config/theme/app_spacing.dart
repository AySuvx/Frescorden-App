// lib/config/theme/app_spacing.dart
//
// Fase 5, Módulo 1 — grilla de espaciado estricta de 8dp. Todo Padding,
// SizedBox y BorderRadius de los componentes atómicos nuevos (ver
// lib/presentation/widgets/common/) y del código tocado en este módulo usa
// estos tokens en vez de números mágicos, para que el ritmo visual quede
// consistente y una futura corrección de espaciado se haga en un solo
// lugar.
//
// Única excepción deliberada: [xs] (4dp, medio paso) para separaciones
// puntuales dentro de un mismo componente compacto (ícono↔texto en un chip,
// por ejemplo) donde 8dp completos se ven desproporcionados. El resto de la
// grilla (paddings de pantalla, márgenes entre tarjetas, radios) respeta
// múltiplos de 8 sin excepción.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  /// Radio de esquina estándar de [CustomCard].
  static const double cardRadius = 16;

  /// Radio de esquina estándar de [PrimaryButton]/[SecondaryButton].
  static const double buttonRadius = 8;

  /// Alto mínimo de botones y objetivos táctiles — cumple el mínimo de
  /// accesibilidad de 44–48dp (ver checklist ui-ux-pro-max, "Touch &
  /// Interaction").
  static const double buttonHeight = 48;
}
