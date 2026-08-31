// lib/presentation/widgets/analytics/analytics_chart_helpers.dart
//
// Gráficos de Analíticas:
// Piezas compartidas entre WasteVsConsumedBarChart y WasteCategoryPieChart
// para no duplicar la leyenda ni el estado "sin datos suficientes".

import 'package:flutter/material.dart';

/// Leyenda de color + etiqueta. Usada tanto con colores fijos (verde/rojo
/// del gráfico de barras) como con colores por categoría (dona).
class ChartLegend extends StatelessWidget {
  final List<(Color, String)> items;

  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: items.map((item) {
        final (color, label) = item;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }
}

/// Mensaje informativo cuando el historial no alcanza para dibujar el
/// gráfico (requisito: "Manejo de Estado Vacío").
class ChartEmptyState extends StatelessWidget {
  final String message;

  const ChartEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
