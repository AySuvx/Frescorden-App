// Genera un PDF con las métricas del Panel Administrativo Global — pensado
// para anexar directo en la documentación del proyecto, sin pasar por
// ningún servidor (ver AdminDashboardScreen._buildReportButton): arma el
// documento del lado del celular a partir de los mismos datos que ya se
// muestran en pantalla.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/admin_stats.dart';

class AdminReportGenerator {
  const AdminReportGenerator._();

  static Future<Uint8List> generate(AdminStats stats) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Fresc(o)rden — Reporte de métricas',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            'Generado el ${now.day}/${now.month}/${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          _section('Usuarios', [
            _row('Usuarios registrados', '${stats.totalUsers}'),
            _row('Nuevos (últimos 7 días)', '${stats.newUsersLast7Days}'),
            _row('Activos (últimos 7 días)', '${stats.activeUsersLast7Days}'),
            _row('Activos (últimos 30 días)', '${stats.activeUsersLast30Days}'),
          ]),
          _section('Hogares', [
            _row('Hogares creados', '${stats.totalHouseholds}'),
            _row('Miembros totales', '${stats.totalHouseholdMembers}'),
            _row(
              'Promedio de miembros por hogar',
              stats.averageMembersPerHousehold.toStringAsFixed(1),
            ),
            _row(
              'Hogares con código de invitación vencido',
              '${stats.householdsWithExpiredInviteCode}',
            ),
          ]),
          _section('Impacto real (últimos 30 días)', [
            _row(
              'Aprovechamiento global',
              stats.globalWasteReductionPercentageLast30Days == null
                  ? 'Sin datos'
                  : '${stats.globalWasteReductionPercentageLast30Days!.toStringAsFixed(0)}%',
            ),
            _row('Consumidos a tiempo', '${stats.globalConsumedLast30Days}'),
            _row('Desperdiciados', '${stats.globalDiscardedLast30Days}'),
          ]),
          _section('Asistente Culinario (IA)', [
            _row(
              'Consultas exitosas (últimos 30 días)',
              '${stats.assistantQueriesLast30Days}',
            ),
            _row(
              'Hogares distintos que lo usaron',
              '${stats.householdsUsingAssistantLast30Days}',
            ),
          ]),
          _section('Usabilidad (SUS + NPS)', [
            _row('Respuestas recibidas', '${stats.usabilitySurveyResponses}'),
            _row(
              'Puntaje SUS promedio (0-100)',
              stats.averageSusScore?.toStringAsFixed(1) ?? 'Sin datos',
            ),
            _row(
              'Net Promoter Score (-100 a 100)',
              stats.netPromoterScore?.toStringAsFixed(0) ?? 'Sin datos',
            ),
          ]),
          if (stats.usabilitySurveyResponses > 0) ...[
            _chartSection(
              'Distribución de puntajes SUS',
              labels: const ['0-20', '20-40', '40-60', '60-80', '80-100'],
              values: stats.susScoreHistogram
                  .map((e) => e.toDouble())
                  .toList(),
              colors: List.filled(
                stats.susScoreHistogram.length,
                PdfColors.indigo300,
              ),
            ),
            _chartSection(
              'Desglose del Net Promoter Score',
              labels: const ['Detractores', 'Pasivos', 'Promotores'],
              values: [
                stats.npsDetractors.toDouble(),
                stats.npsPassives.toDouble(),
                stats.npsPromoters.toDouble(),
              ],
              colors: [PdfColors.red300, PdfColors.amber300, PdfColors.green300],
            ),
            _chartSection(
              'Promedio por ítem del SUS (escala 1-5)',
              labels: [
                for (var i = 1; i <= stats.susItemAverages.length; i++) '$i',
              ],
              values: stats.susItemAverages,
              colors: List.filled(
                stats.susItemAverages.length,
                PdfColors.teal300,
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Título + gráfico de barras simple dibujado a mano con primitivas del
  /// paquete `pdf` (Row/Column/Container proporcionales) — no depende de
  /// fl_chart (que requiere un árbol de widgets Flutter en pantalla, no
  /// disponible al generar el PDF en segundo plano).
  static pw.Widget _chartSection(
    String title, {
    required List<String> labels,
    required List<double> values,
    required List<PdfColor> colors,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          _barChart(labels: labels, values: values, colors: colors),
        ],
      ),
    );
  }

  static pw.Widget _barChart({
    required List<String> labels,
    required List<double> values,
    required List<PdfColor> colors,
  }) {
    const chartHeight = 70.0;
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < labels.length; i++)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  values[i] == values[i].roundToDouble()
                      ? values[i].toInt().toString()
                      : values[i].toStringAsFixed(1),
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 3),
                pw.Container(
                  height: chartHeight * (values[i] / safeMax),
                  margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                  color: colors[i],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  labels[i],
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _section(String title, List<pw.Widget> rows) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
