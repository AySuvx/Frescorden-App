// Speed Dial con dos acciones, cada una con su propio flujo de navegación:
//   - "Agregar por Categoría": abre primero CategoryPickerScreen (grid de
//     categorías) y luego AddProductScreen con esa categoría preseleccionada.
//   - "Registro a Granel": va directo al mismo formulario, pre-configurado
//     para perecederos comprados a granel (plaza/mercado) — sin paso de
//     selección de categoría — ver AddProductScreen(isBulkEntry: true).
//
// Es el botón más tocado de toda la app, así que usa física de resorte
// real (SpringSimulation, no una curva implícita) para abrir/cerrar: las
// dos opciones "saltan" con un leve rebote en vez de deslizarse en línea
// recta — ver PressableScale para el mismo criterio aplicado a tarjetas y
// botones normales.

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../config/theme/app_spacing.dart';

class ButtonPlus extends StatefulWidget {
  final VoidCallback onManualAdd;
  final VoidCallback onBulkAdd;

  const ButtonPlus({
    super.key,
    required this.onManualAdd,
    required this.onBulkAdd,
  });

  @override
  State<ButtonPlus> createState() => _ButtonPlusState();
}

class _ButtonPlusState extends State<ButtonPlus>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller;

  static const _spring = SpringDescription(mass: 1, stiffness: 300, damping: 15);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, lowerBound: 0, upperBound: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleMenu() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _isExpanded = !_isExpanded);
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, _isExpanded ? 1 : 0, 0),
    );
  }

  Widget _buildSpeedDialButton({
    required String heroTag,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required String iconAsset,
    required String label,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // El resorte puede pasarse un poco de 0/1 (el rebote) — se usa tal
        // cual para la posición/escala (el rebote SE VE), pero se recorta
        // para la opacidad (un alpha fuera de 0-1 no es válido).
        final t = _controller.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 44),
            child: Transform.scale(
              scale: 0.7 + (0.3 * t).clamp(0.0, 0.3),
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: () {
          onPressed();
          toggleMenu();
        },
        backgroundColor: backgroundColor,
        icon: Image.asset(iconAsset, width: 24, height: 24),
        label: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botón Registro a Granel (perecederos de plaza/mercado)
        _buildSpeedDialButton(
          heroTag: 'bulkAdd',
          onPressed: widget.onBulkAdd,
          backgroundColor: const Color(0xFF42A5F5),
          iconAsset: 'assets/iconos/fresco_accion_granel.png',
          label: 'Registro a Granel',
        ),
        const SizedBox(height: AppSpacing.md),

        // Botón Agregar por Categoría (flujo estándar)
        _buildSpeedDialButton(
          heroTag: 'manualAdd',
          onPressed: widget.onManualAdd,
          backgroundColor: const Color(0xFF66BB6A),
          iconAsset: 'assets/iconos/fresco_accion_categoria.png',
          label: 'Agregar por Categoría',
        ),
        const SizedBox(height: AppSpacing.md),

        // Botón principal (mascota) — gira levemente al abrir/cerrar, con
        // el mismo resorte que las opciones, para reforzar el cambio de
        // estado sin necesitar texto ni un ícono "+/x" distinto.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 0.78, // ~45° en el punto de reposo
              child: child,
            );
          },
          child: Tooltip(
            message: _isExpanded ? 'Cerrar opciones' : 'Agregar nuevo producto',
            child: FloatingActionButton.large(
              heroTag: 'toggleMenu',
              onPressed: toggleMenu,
              backgroundColor: Colors.transparent,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              child: Image.asset(
                'assets/Frescorden-logo/fresco-fresh-512.png',
                width: 72.0,
                height: 72.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
