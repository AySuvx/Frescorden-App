// lib/presentation/widgets/common/custom_card.dart
//
// Componentización Atómica.
// Tarjeta base del sistema de diseño. Envuelve un [Card] normal y delega
// color/elevación/forma en CardThemeData (ver AppTheme) para que quede
// adaptable a claro/oscuro sin que cada pantalla repita esos valores —
// exactamente el patrón que antes producía tarjetas con `Colors.white`,
// `Colors.grey[200]`, etc. hardcodeados (ver recetas_screen.dart,
// shopping_list_screen.dart antes del fix de contraste de modo oscuro).
// Solo expone lo que legítimamente varía tarjeta a tarjeta: contenido,
// padding, margen, un color semántico puntual (p. ej. errorContainer para
// "presupuesto superado") y un onTap opcional.
import 'package:flutter/material.dart';
import '../../../config/theme/app_spacing.dart';
import 'pressable_scale.dart';

class CustomCard extends StatelessWidget {
  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// Override puntual del color de fondo (p. ej. un estado de error/éxito).
  /// Si es `null`, hereda el color de tarjeta del tema activo.
  final Color? color;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // PressableScale solo observa presionar/soltar (no reclama el tap):
    // el InkWell de abajo sigue siendo el único dueño del gesto y del
    // ripple — ver la nota de diseño en pressable_scale.dart.
    return PressableScale(
      enabled: onTap != null,
      child: Card(
        margin: margin,
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
