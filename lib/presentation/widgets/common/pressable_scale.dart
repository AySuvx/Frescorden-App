// Física de resortes REAL (no una curva que la simula) para cualquier
// elemento tocable: se encoge al presionar y, al soltar, rebota como un
// resorte de verdad — pasa levemente de su tamaño normal antes de
// asentarse, en vez de simplemente volver en línea recta. Usa
// SpringSimulation (package:flutter/physics.dart) sobre un
// AnimationController, el mismo mecanismo que usa Flutter internamente
// para gestos como el "snap" de un Scrollable al soltar.
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
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

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

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pressed = false;

  /// Tunning del resorte: `stiffness` alta + `damping` moderado da un
  /// rebote corto y perceptible sin llegar a sentirse "gelatinoso" ni
  /// tardar demasiado en asentarse (ver SpringDescription).
  static const _spring = SpringDescription(mass: 1, stiffness: 600, damping: 18);

  @override
  void initState() {
    super.initState();
    // lowerBound/upperBound con margen: el valor de reposo es 1.0, baja
    // hasta `widget.scale` al presionar, y el resorte puede pasarse
    // brevemente por encima de 1.0 al soltar antes de asentarse ahí.
    _controller = AnimationController(
      vsync: this,
      value: 1,
      lowerBound: 0.8,
      upperBound: 1.1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);

    if (value) {
      HapticFeedback.lightImpact();
      // Presionar: rápido y amortiguado, sin rebote (el rebote es la
      // sorpresa agradable de SOLTAR, no de apretar).
      _controller.animateTo(
        widget.scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else {
      // Soltar: resorte físico real hacia 1.0 — se pasa un poco y
      // rebota de vuelta, en vez de volver en línea recta.
      _controller.animateWith(
        SpringSimulation(_spring, _controller.value, 1, 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}
