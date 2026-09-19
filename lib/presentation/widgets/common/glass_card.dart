// Acabado "cristal esmerilado": BackdropFilter difumina lo que hay
// detrás y un relleno translúcido dejа
// entrever ese blur, con un borde de 1dp apenas visible que separa la
// tarjeta del fondo. Reservado para elementos que flotan SOBRE contenido
// (diálogos, la barra de cuota del asistente, el resumen del hogar) — no
// reemplaza a `CustomCard` en listas normales, donde una superficie sólida
// sigue siendo más legible.
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_spacing.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppSpacing.cardRadius,
    this.blurSigma = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    // #1E1E1E al 75% en oscuro (brief); en claro, blanco algo más
    // translúcido — a plena opacidad el blur de atrás no se notaría.
    final fill = (isDark ? AppColors.cardDark : AppColors.cardLight)
        .withValues(alpha: isDark ? 0.75 : 0.65);
    final borderColor = colorScheme.onSurface.withValues(alpha: 0.12);
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
