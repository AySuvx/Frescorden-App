// lib/presentation/widgets/common/status_badge.dart
//
// Fase 5, Módulo 1 — Componentización Atómica.
// Chip semántico de estado de vencimiento. Reemplaza los `Text` sueltos con
// color hardcodeado según días restantes (ver
// ProductosScreen._getExpirationColor: Colors.red/orange/green fijos, sin
// distinguir claro/oscuro) por un único componente que resuelve color +
// ícono + contraste AA para los 3 estados, en ambos modos, vía los roles
// container/onContainer del ColorScheme (ver AppTheme).
import 'package:flutter/material.dart';
import '../../../config/theme/app_spacing.dart';

enum ProductFreshness {
  fresh,
  expiringSoon,
  expired;

  /// Deriva el estado a partir de los días restantes para el vencimiento.
  /// Mismo umbral que usaba el código anterior (<=3 días = "por vencer").
  static ProductFreshness fromDaysRemaining(int daysRemaining) {
    if (daysRemaining < 0) return ProductFreshness.expired;
    if (daysRemaining <= 3) return ProductFreshness.expiringSoon;
    return ProductFreshness.fresh;
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final ProductFreshness status;

  /// Texto a mostrar; si es `null` usa la etiqueta por defecto del estado.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon, String defaultLabel) =
        switch (status) {
          ProductFreshness.fresh => (
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
            Icons.check_circle,
            'Fresco',
          ),
          ProductFreshness.expiringSoon => (
            colorScheme.tertiaryContainer,
            colorScheme.onTertiaryContainer,
            Icons.warning_amber,
            'Por vencer',
          ),
          ProductFreshness.expired => (
            colorScheme.errorContainer,
            colorScheme.onErrorContainer,
            Icons.error,
            'Vencido',
          ),
        };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label ?? defaultLabel,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
