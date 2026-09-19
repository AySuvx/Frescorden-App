// Chip semántico de estado de vencimiento: un único componente que
// resuelve color + ícono + contraste AA para los 3 estados, en ambos
// modos, vía los roles container/onContainer del ColorScheme (ver AppTheme).
import 'package:flutter/material.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../domain/entities/product_freshness.dart';

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
          // Fase 6, Módulo 3: un label largo (ej. "Tienes 1 de 4
          // ingredientes") desbordaba el Row en pantallas angostas cuando
          // el badge comparte espacio con otro contenido (ej. la miniatura
          // de una receta) — mismo bug que PrimaryButton, mismo fix.
          Flexible(
            child: Text(
              label ?? defaultLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
