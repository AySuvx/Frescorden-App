// Molde compartido de los gráficos del Panel Administrativo Global
// (SusHistogramChart, SusItemAveragesChart, SusScoreDotPlot): tarjeta con
// título, subtítulo y el contenido propio de cada gráfico.

import 'package:flutter/material.dart';

class AdminChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AdminChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
