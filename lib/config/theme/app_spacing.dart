// Grilla de espaciado de 8dp: todo Padding/SizedBox/BorderRadius de los
// componentes usa estos tokens en vez de números mágicos, para que una
// corrección de espaciado se haga en un solo lugar.
//
// Única excepción: [xs] (4dp, medio paso) para separaciones puntuales
// dentro de un componente compacto (ícono↔texto en un chip) donde 8dp
// completos se ven desproporcionados. El resto respeta múltiplos de 8.
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
