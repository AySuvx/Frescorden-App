// lib/presentation/widgets/common/skeleton_loader.dart
//
// Fase 5, Módulo 3 — reemplaza los `CircularProgressIndicator` centrados
// mientras se leen datos de Firestore (ProductosScreen, ShoppingListScreen,
// AnalyticsScreen) por placeholders con forma de contenido real y efecto
// shimmer. Un spinner solo dice "espera"; un skeleton además anticipa el
// layout final, así la pantalla no "salta" cuando llegan los datos.
//
// Sin el paquete `shimmer`: la animación es un único `AnimationController`
// barriendo un `LinearGradient`, no amerita una dependencia extra.
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_spacing.dart';

/// Bloque rectangular individual con efecto shimmer — la pieza atómica de
/// cualquier skeleton. Colores tomados del tema activo: en oscuro usa
/// literalmente `AppColors.cardDark` (#1E1E1E, el mismo que ya pintan las
/// tarjetas reales) para que el placeholder se funda con lo que reemplaza;
/// en claro usa `surfaceContainerHighest` (un gris perceptible sobre el
/// fondo casi blanco de la app, sin inventar un hex nuevo).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.xs,
  });

  /// `null` deja que el padre decida el ancho (p. ej. dentro de un
  /// `Expanded`); no usa `double.infinity` directo para no repetir el
  /// riesgo de ancho infinito ya documentado en `AppTheme`.
  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final base = isDark ? AppColors.cardDark : colorScheme.surfaceContainerHighest;
    final highlight = Color.lerp(base, colorScheme.onSurface, isDark ? 0.10 : 0.07)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Barre el degradado de izquierda a derecha y vuelve a empezar —
        // el franja clara ("highlight") recorre el bloque en cada ciclo.
        final sweep = Tween<double>(begin: -1.5, end: 1.5).transform(
          _controller.value,
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(sweep - 0.5, 0),
              end: Alignment(sweep + 0.5, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton de una lista de "tarjetas con imagen + 2 líneas de texto" —
/// cubre el caso más común (ProductosScreen, ítems de ShoppingListScreen).
/// Para formas distintas (gráficos de AnalyticsScreen) se compone
/// directamente con [SkeletonBox] en la propia pantalla.
///
/// Es un `Column` (no un `ListView` propio) para poder usarse tanto como
/// cuerpo completo de una pantalla (envuelto en un scroll por quien lo usa,
/// si hace falta) como *dentro* de un `ListView` ya existente — ver
/// ShoppingListScreen, donde reemplaza un ítem intermedio de su propio
/// `ListView` y anidar dos scrollables ahí habría sido un error de layout.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.showLeading = true,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final int itemCount;

  /// Algunas listas (ShoppingListScreen) no tienen imagen/avatar por ítem.
  final bool showLeading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == itemCount - 1 ? 0 : AppSpacing.sm,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      if (showLeading) ...[
                        SkeletonBox(
                          width: 50,
                          height: 50,
                          borderRadius: AppSpacing.sm,
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(height: 16),
                            const SizedBox(height: AppSpacing.sm),
                            SkeletonBox(height: 12, width: 120),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
