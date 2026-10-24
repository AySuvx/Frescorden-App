// test/quota_service_test.dart
//
// BDD de QuotaService (lib/presentation/utils/quota_service.dart): cuota
// diaria de consultas a Gemini persistida en SharedPreferences (mockeado
// con setMockInitialValues, sin depender de una plataforma real).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/presentation/utils/quota_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Historia de Usuario: Como usuario, quiero tener un límite diario '
      'de consultas a la IA', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'Escenario: sin consultas previas, quedan disponibles todas las del '
      'límite diario',
      () async {
        final remaining = await QuotaService.instance.getRemaining();

        expect(remaining, QuotaService.dailyLimit);
      },
    );

    test(
      'Escenario: cada consulta exitosa descuenta una unidad de la cuota',
      () async {
        final remaining = await QuotaService.instance.recordSuccessfulQuery();

        expect(remaining, QuotaService.dailyLimit - 1);
        expect(await QuotaService.instance.getRemaining(), QuotaService.dailyLimit - 1);
      },
    );

    test(
      'Escenario: la cuota nunca baja de cero aunque se registren más '
      'consultas que el límite',
      () async {
        for (var i = 0; i < QuotaService.dailyLimit + 3; i++) {
          await QuotaService.instance.recordSuccessfulQuery();
        }

        expect(await QuotaService.instance.getRemaining(), 0);
      },
    );

    test(
      'Escenario: si cambia el día almacenado, la cuota se reinicia sola',
      () async {
        SharedPreferences.setMockInitialValues({
          'assistant_daily_query_count': QuotaService.dailyLimit,
          'assistant_daily_query_date': '2000-01-01',
        });

        final remaining = await QuotaService.instance.getRemaining();

        expect(remaining, QuotaService.dailyLimit);
      },
    );

    test(
      'Escenario: nextResetAt siempre cae a medianoche del día siguiente',
      () {
        final resetAt = QuotaService.instance.nextResetAt();
        final now = DateTime.now();
        final expected = DateTime(now.year, now.month, now.day + 1);

        expect(resetAt, expected);
        expect(resetAt.hour, 0);
        expect(resetAt.minute, 0);
      },
    );
  });
}
