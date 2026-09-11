// lib/presentation/widgets/common/secondary_button.dart
//
// Fase 5, Módulo 1 — Componentización Atómica.
// Acción secundaria (menor énfasis visual que PrimaryButton): mismo
// contrato y misma retroalimentación táctil, apoyado en
// OutlinedButtonThemeData (ver AppTheme) en vez de ElevatedButtonThemeData.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_spacing.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;

    final button = OutlinedButton(
      onPressed:
          disabled
              ? null
              : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
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
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}
