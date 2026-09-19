// Diálogo de confirmación con acabado de cristal: el contenido detrás se
// difumina (`BackdropFilter`
// animado con la transición) y la propia tarjeta deja entrever ese blur a
// través de su relleno translúcido (ver [GlassCard]).
//
// Reemplaza puntualmente `showDialog(builder: (ctx) => AlertDialog(...))`
// en los diálogos de CONFIRMACIÓN (expulsar miembro, salir del hogar,
// eliminar cuenta, retirar producto) — el resto (selector de idioma,
// avisos informativos de permisos) sigue con el `AlertDialog` estándar:
// no todos los modales necesitan este acabado, y aplicarlo sin criterio
// le restaría protagonismo justo a los que sí conviene destacar.
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme/app_spacing.dart';
import 'glass_card.dart';

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final colorScheme = Theme.of(ctx).colorScheme;
      // `showGeneralDialog` (a diferencia de `showDialog` + `AlertDialog`,
      // que envuelven todo en un `Dialog`/`Material` por dentro) NO pone
      // un `Material` ancestro para el contenido del `pageBuilder`. Sin
      // uno, cualquier `Text` de acá renderiza con el estilo de depuración
      // de Flutter para "falta un DefaultTextStyle" (gigante, subrayado
      // amarillo) — hallazgo real al probar en dispositivo.
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    child: content,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: AppSpacing.xs,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10 * curved.value,
              sigmaY: 10 * curved.value,
            ),
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );
    },
  );
}
