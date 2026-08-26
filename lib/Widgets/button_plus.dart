// lib/Widgets/button_plus.dart
//
// FIX #C2: después de `await Navigator.push` (escaneo de QR) se llamaba a
//   widget.onScanComplete() y toggleMenu() sin verificar que el widget
//   seguía montado. Si el usuario navegaba atrás durante el escaneo, la
//   llamada a setState() dentro de toggleMenu() lanzaba
//   "setState called on disposed widget".
//   FIX: añadido `if (!mounted) return;` antes de cualquier uso de estado
//   post-await.

import 'package:flutter/material.dart';
import '../screens/qr_scanner_page.dart';

class ButtonPlus extends StatefulWidget {
  final Function(String) onScanComplete;
  final VoidCallback onManualAdd;

  const ButtonPlus({
    super.key,
    required this.onScanComplete,
    required this.onManualAdd,
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
        // Botón Escanear con código
        AnimatedSlide(
          offset: _isExpanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton.extended(
              heroTag: 'scanQR',
              onPressed: () async {
                final String? scannedCode = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const QRScannerPage()),
                );
                // FIX #C2: guardia mounted antes de usar estado o callbacks
                if (!mounted) return;
                if (scannedCode != null && scannedCode.isNotEmpty) {
                  widget.onScanComplete(scannedCode);
                }
                toggleMenu();
              },
              backgroundColor: const Color(0xFF42A5F5),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text(
                'Agregar con código',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botón Agregar sin código
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
                'Agregar sin código',
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
