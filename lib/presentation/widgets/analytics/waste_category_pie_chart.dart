// lib/presentation/widgets/analytics/waste_category_pie_chart.dart
//
// Gráficos de Analíticas:
// Dona con la proporción de productos VENCIDOS por categoría (sobre el
// total de vencidos, no sobre el total del historial — este gráfico solo
// habla de dónde se concentra el desperdicio). Consume AnalyticsProvider
// directamente, igual que WasteVsConsumedBarChart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../utils/food_category_ui.dart';
import 'analytics_chart_helpers.dart';

class WasteCategoryPieChart extends StatelessWidget {
  const WasteCategoryPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AnalyticsProvider>().summary;
    // Solo categorías con al menos un producto vencido: este gráfico
    // representa la DISTRIBUCIÓN del desperdicio, no el inventario sano.
    final wasteData = summary.categoryBreakdown
        .where((c) => c.expired > 0)
        .toList()
      ..sort((a, b) => b.expired.compareTo(a.expired));
    final totalExpired = wasteData.fold<int>(0, (sum, c) => sum + c.expired);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribución de pérdidas por categoría',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '% de productos vencidos, por categoría',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (wasteData.isEmpty)
              const ChartEmptyState(
                message: '¡Sin desperdicio registrado todavía! 🎉\n'
                    'Este gráfico se llenará si algún producto vence.',
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: [
                      for (final stats in wasteData)
                        PieChartSectionData(
                          value: stats.expired.toDouble(),
                          color: stats.category.chartColor,
                          radius: 54,
                          title:
                              '${(stats.expired / totalExpired * 100).round()}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ChartLegend(
                items: [
                  for (final stats in wasteData)
                    (stats.category.chartColor, stats.category.label),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
