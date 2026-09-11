// lib/screens/analytics_screen.dart
//
// Capa de Presentación: KPIs numéricos + gráficos (fl_chart).
// Consume AnalyticsProvider, que a su vez llama a GetAnalyticsUseCase.
// Household-aware: la carga inicial la dispara AnalyticsProvider solo, al
// enterarse del hogar activo (ver ChangeNotifierProxyProvider en main.dart)
// — esta pantalla solo dispara loadSummary() en el pull-to-refresh.
//
// Estado vacío: un hogar nuevo (o que nunca eliminó un producto en el
// último mes) no tiene historial todavía. En vez de mostrar 0% / $0 de
// forma engañosa, se muestra un mensaje explicando por qué no hay datos aún
// (AnalyticsSummary.hasData). Los gráficos individuales manejan además su
// propio estado vacío más específico (ver WasteVsConsumedBarChart /
// WasteCategoryPieChart) para el caso en que sí hay KPIs pero el desglose
// por categoría todavía es insuficiente.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/analytics_summary.dart';
import '../domain/entities/product_history_entry.dart';
import '../presentation/providers/analytics_provider.dart';
import '../presentation/utils/food_category_ui.dart';
import '../presentation/widgets/analytics/waste_vs_consumed_bar_chart.dart';
import '../presentation/widgets/analytics/waste_category_pie_chart.dart';
import '../presentation/utils/currency_format.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();
    final AnalyticsSummary summary = provider.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analíticas'),
        backgroundColor: Colors.green,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !summary.hasData
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => provider.loadSummary(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Basado en ${summary.totalResolved} producto'
                        '${summary.totalResolved == 1 ? '' : 's'} resuelto'
                        '${summary.totalResolved == 1 ? '' : 's'} en el '
                        'último mes',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildKpiCard(
                        icon: Icons.eco,
                        color: Colors.green,
                        label: 'Aprovechamiento del último mes',
                        value:
                            '${summary.wasteReductionPercentage.toStringAsFixed(0)}%',
                        subtitle: 'Consumidos vs. desperdiciados',
                      ),
                      _buildKpiCard(
                        icon: Icons.savings,
                        color: Colors.teal,
                        label: 'Dinero ahorrado (estimado)',
                        value: summary.moneySavedCop.asCop,
                        subtitle: 'Al no desperdiciar lo consumido a tiempo',
                      ),
                      _buildKpiCard(
                        icon: Icons.autorenew,
                        color: Colors.blue,
                        label: 'Rotación promedio',
                        value:
                            '${summary.averageRotationDays.toStringAsFixed(1)} días',
                        subtitle: 'Tiempo promedio en tu inventario',
                      ),
                      _buildKpiCard(
                        icon: Icons.warning_amber,
                        color: Colors.deepOrange,
                        label: 'Categoría con más vencimientos',
                        value: summary.worstExpirationCategory?.label ??
                            'Sin datos',
                        subtitle: 'La que más se vence antes de consumirse',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Top Alimentos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTopProductsCard(summary),
                      const SizedBox(height: 20),
                      const Text(
                        'Detalle por categoría',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const WasteVsConsumedBarChart(),
                      const WasteCategoryPieChart(),
                      const SizedBox(height: 8),
                      const Text(
                        'Desglose Histórico',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Alimentos marcados como desperdiciados en el último mes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildDiscardedBreakdownCard(summary.discardedBreakdown),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTopProductsCard(AnalyticsSummary summary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x2666BB6A),
              child: Icon(Icons.emoji_events, color: Colors.green),
            ),
            title: const Text('Más consumido'),
            subtitle: Text(
              summary.topConsumedProduct?.name ?? 'Sin datos',
            ),
            trailing: summary.topConsumedProduct == null
                ? null
                : Text(
                    '${summary.topConsumedProduct!.count}x',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x26EF5350),
              child: Icon(Icons.delete_forever, color: Colors.deepOrange),
            ),
            title: const Text('Más desperdiciado'),
            subtitle: Text(
              summary.topDiscardedProduct?.name ?? 'Sin datos',
            ),
            trailing: summary.topDiscardedProduct == null
                ? null
                : Text(
                    '${summary.topDiscardedProduct!.count}x',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardedBreakdownCard(List<ProductHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '¡Sin desperdicio registrado este mes! 🎉',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final entry in entries) ...[
            ListTile(
              dense: true,
              leading: Icon(entry.category.icon, color: Colors.deepOrange),
              title: Text(entry.name),
              subtitle: Text(entry.category.label),
              trailing: Text(
                _formatShortDate(entry.resolvedAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            if (entry != entries.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  String _formatShortDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}';
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 26,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Todavía no hay datos suficientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Las analíticas se calculan a partir de los productos que '
              'elimines de tu inventario (consumidos o vencidos). '
              'Vuelve aquí después de usar la app un tiempo.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
