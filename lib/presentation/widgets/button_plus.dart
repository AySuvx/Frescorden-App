// Speed Dial con dos acciones, cada una con su propio flujo de navegación:
//   - "Agregar por Categoría": abre primero CategoryPickerScreen (grid de
//     categorías) y luego AddProductScreen con esa categoría preseleccionada.
//   - "Registro a Granel": va directo al mismo formulario, pre-configurado
//     para perecederos comprados a granel (plaza/mercado) — sin paso de
//     selección de categoría — ver AddProductScreen(isBulkEntry: true).

import 'package:flutter/material.dart';

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
              icon: const Icon(Icons.shopping_basket, color: Colors.white),
              label: const Text(
                'Registro a Granel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

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
              icon: const Icon(Icons.eco, color: Colors.white),
              label: const Text(
                'Agregar por Categoría',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botón principal (Manzanita)
        Tooltip(
          message: _isExpanded ? 'Cerrar opciones' : 'Agregar nuevo producto',
          child: FloatingActionButton(
            heroTag: 'toggleMenu',
            onPressed: toggleMenu,
            backgroundColor: Colors.transparent,
            child: Image.asset(
              'assets/manzana.png',
              width: 75.0,
              height: 75.0,
            ),
          ),
        ),
      ],
    );
  }
}
