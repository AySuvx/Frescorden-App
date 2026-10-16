// Número que sube animado desde 0 hasta su valor real al aparecer en
// pantalla, en vez de mostrarse estático de una — usado en tarjetas de KPI
// (Inicio, Analíticas, Panel Administrativo) para que esas pantallas se
// sientan menos "planas". Puramente visual: el valor final siempre es el
// mismo, solo cambia cómo llega a verse.
import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.suffix = '',
  });

  final num value;
  final TextStyle? style;
  final Duration duration;

  /// Ej. `"\$ "` para dinero — va ANTES del número animado.
  final String prefix;

  /// Ej. `"%"` — va DESPUÉS del número animado.
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final display = value == value.roundToDouble()
            ? animatedValue.round().toString()
            : animatedValue.toStringAsFixed(1);
        return Text('$prefix$display$suffix', style: style);
      },
    );
  }
}
