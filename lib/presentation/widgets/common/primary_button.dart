// lib/presentation/widgets/common/primary_button.dart
//
// Componentización Atómica.
// Botón de acción principal. Se apoya en ElevatedButtonThemeData (ver
// AppTheme) para color/forma/alto mínimo táctil, y añade lo que el tema no
// puede resolver por sí solo: `HapticFeedback.lightImpact()` en cada toque
// y un estado de carga integrado, para no repetir ese mismo patrón ad-hoc
// en cada pantalla con una acción async (guardar, enviar, confirmar).
//
// El "InkWell" táctil que pide el brief lo aporta Material internamente:
// ElevatedButton ya construye su propio InkResponse con ripple, estados
// hover/pressed/disabled y foco — reimplementarlo a mano con
// GestureDetector+InkWell perdería ese comportamiento sin ganar nada.
//
// El escalado sutil al presionar y su háptico ahora
// los da [PressableScale] (en el press-down, más inmediato que esperar a
// que el tap se complete) — se quita el `HapticFeedback.lightImpact()`
// que este botón disparaba antes en `onPressed` para no vibrar dos veces
// por el mismo toque.
import 'package:flutter/material.dart';
import '../../../config/theme/app_spacing.dart';
import 'pressable_scale.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;

  /// `null` deshabilita el botón (igual que en ElevatedButton estándar).
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Si es `true` (default), el botón ocupa todo el ancho disponible —
  /// el patrón más común en formularios/CTAs de la app. En `false` se
  /// ajusta a su contenido (p. ej. varios botones uno junto a otro).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;

    final button = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );

    final sized = expand ? SizedBox(width: double.infinity, child: button) : button;
    return PressableScale(enabled: !disabled, child: sized);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.color,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (icon == null) {
      return Text(label, overflow: TextOverflow.ellipsis, maxLines: 1);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        // Fase 6, Módulo 3: un label largo (ej. "Crear Receta Colombiana
        // con IA") desbordaba el Row en pantallas angostas — el Text no
        // tenía Flexible, así que tomaba su ancho natural sin ajustarse al
        // espacio disponible dentro del botón.
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
    );
  }
}
