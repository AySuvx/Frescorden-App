// Física de resortes sutil para cualquier elemento tocable: se encoge
// levemente al presionar y vuelve a
// su tamaño con una curva suave, además de un golpecito háptico.
//
// Usa `Listener` (eventos de puntero crudos) en vez de `GestureDetector`
// a propósito: este widget SOLO observa presionar/soltar para animar la
// escala, nunca reclama el gesto de tap en sí. Así puede envolver
// `CustomCard` (que ya tiene su propio `InkWell.onTap`) o
// `PrimaryButton`/`SecondaryButton` (que ya tienen su propio
// `ElevatedButton.onPressed`) sin competir por el mismo toque en el
// "gesture arena" — evita el riesgo real de que el tap se dispare dos
// veces o que el ripple del InkWell deje de reconocerse.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
  });

  final Widget child;

  /// Factor de escala al presionar (0.96 = brief).
  final double scale;

  /// `false` para tarjetas/botones deshabilitados — no reacciona ni
  /// vibra si de todos modos no hay ninguna acción detrás del toque.
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
    if (value) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: widget.child
          .animate(target: _pressed ? 1 : 0)
          .scaleXY(
            begin: 1,
            end: widget.scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOutCubic,
          ),
    );
  }
}
