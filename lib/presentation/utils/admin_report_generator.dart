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
        ],
      ),
    );

    return doc.save();
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
