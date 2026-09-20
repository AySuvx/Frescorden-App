// Speed Dial con dos acciones, cada una con su propio flujo de navegación:
//   - "Agregar por Categoría": abre primero CategoryPickerScreen (grid de
//     categorías) y luego AddProductScreen con esa categoría preseleccionada.
//   - "Registro a Granel": va directo al mismo formulario, pre-configurado
//     para perecederos comprados a granel (plaza/mercado) — sin paso de
//     selección de categoría — ver AddProductScreen(isBulkEntry: true).

import 'package:flutter/material.dart';
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

class _ButtonPlusState extends State<ButtonPlus> {
  bool _isExpanded = false;

  void toggleMenu() {
    if (!mounted) return;
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botón Registro a Granel (perecederos de plaza/mercado)
        AnimatedSlide(
          offset: _isExpanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton.extended(
              heroTag: 'bulkAdd',
              onPressed: () {
                widget.onBulkAdd();
                toggleMenu();
              },
              backgroundColor: const Color(0xFF42A5F5),
              icon: Image.asset(
                'assets/iconos/fresco_accion_granel.png',
                width: 24,
                height: 24,
              ),
              label: const Text(
                'Registro a Granel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Botón Agregar por Categoría (flujo estándar)
        AnimatedSlide(
          offset: _isExpanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton.extended(
              heroTag: 'manualAdd',
              onPressed: () {
                widget.onManualAdd();
                toggleMenu();
              },
              backgroundColor: const Color(0xFF66BB6A),
              icon: Image.asset(
                'assets/iconos/fresco_accion_categoria.png',
                width: 24,
                height: 24,
              ),
              label: const Text(
                'Agregar por Categoría',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Botón principal (mascota)
        Tooltip(
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
      ],
    );
  }
}
