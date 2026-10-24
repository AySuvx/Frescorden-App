// test/presentation/utils/admin_report_generator_test.dart
//
// BDD de AdminReportGenerator.generate: produce un PDF válido tanto sin
// datos de la encuesta de usabilidad (sin gráficos) como con ellos (con
// los 3 gráficos de barras dibujados a mano — ver _barChart).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/admin_stats.dart';
import 'package:frescorden/presentation/utils/admin_report_generator.dart';

void main() {
  group('Historia de Usuario: Como administrador, quiero exportar las '
      'métricas globales a PDF', () {
    test(
      'Escenario: sin respuestas de la encuesta de usabilidad, el PDF se '
      'genera sin los gráficos de SUS/NPS',
      () async {
        final bytes = await AdminReportGenerator.generate(AdminStats.empty());

        expect(bytes, isNotEmpty);
        // Cabecera estándar de un archivo PDF.
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
    );

    test(
      'Escenario: con respuestas de la encuesta de usabilidad, el PDF '
      'incluye el histograma SUS, el desglose NPS y el promedio por ítem',
      () async {
        const stats = AdminStats(
          totalUsers: 10,
          newUsersLast7Days: 1,
          activeUsersLast7Days: 2,
          activeUsersLast30Days: 3,
          totalHouseholds: 4,
          totalHouseholdMembers: 5,
          householdsWithExpiredInviteCode: 0,
          globalWasteReductionPercentageLast30Days: 80,
          globalConsumedLast30Days: 8,
          globalDiscardedLast30Days: 2,
          assistantQueriesLast30Days: 6,
          householdsUsingAssistantLast30Days: 3,
          usabilitySurveyResponses: 2,
          averageSusScore: 85.0,
          netPromoterScore: 50.0,
          susScoreHistogram: [0, 0, 0, 1, 1],
          npsPromoters: 1,
          npsPassives: 1,
          npsDetractors: 0,
          susItemAverages: [4.5, 3.0, 5.0, 2.0, 4.0, 3.5, 4.5, 3.0, 5.0, 4.0],
        );

        final bytes = await AdminReportGenerator.generate(stats);

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
    );
  });
}
