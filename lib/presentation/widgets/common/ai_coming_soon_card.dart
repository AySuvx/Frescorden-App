// Reemplazo visual de una función de IA mientras la cuota gratuita
// compartida del proyecto (Gemini) está restringida solo al admin (ver
// AuthProvider.isAdmin). Un solo widget reutilizado en los 3 puntos donde
// hoy se ofrece IA (reconocimiento de producto, receta con IA, asistente)
// en vez de tres pantallas/tutoriales distintos.

import 'package:flutter/material.dart';

import '../../../config/theme/app_spacing.dart';

class AiComingSoonCard extends StatefulWidget {
  const AiComingSoonCard({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  State<AiComingSoonCard> createState() => _AiComingSoonCardState();
}

class _AiComingSoonCardState extends State<AiComingSoonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.92,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/iconos/fresco_receta_ia.png',
                width: 44,
                height: 44,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'MUY PRONTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
