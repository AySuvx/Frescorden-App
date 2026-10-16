// test/presentation/providers/notification_settings_provider_test.dart
//
// BDD de NotificationSettingsProvider: persiste la antelación elegida en
// Ajustes y la refleja en ExpirationAlertPolicy.leadDays, el único lugar
// que NotificationService/los casos de uso de producto ya consultaban.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frescorden/domain/utils/expiration_alert_policy.dart';
import 'package:frescorden/presentation/providers/notification_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ExpirationAlertPolicy.setLeadDays(ExpirationAlertPolicy.defaultLeadDays);
  });

  group('Historia de Usuario: Como usuario, quiero elegir con cuántos días '
      'de antelación me avisa la app', () {
    test(
      'Escenario: sin preferencia guardada, arranca en el valor por defecto',
      () {
        final provider = NotificationSettingsProvider();

        expect(provider.leadDays, ExpirationAlertPolicy.defaultLeadDays);
      },
    );

    test(
      'Escenario: cambiar la antelación la refleja de inmediato en '
      'ExpirationAlertPolicy.leadDays',
      () async {
        final provider = NotificationSettingsProvider();

        await provider.setLeadDays(5);

        expect(provider.leadDays, 5);
        expect(ExpirationAlertPolicy.leadDays, 5);
      },
    );

    test(
      'Escenario: un valor fuera de rango se recorta antes de guardarse',
      () async {
        final provider = NotificationSettingsProvider();

        await provider.setLeadDays(99);

        expect(provider.leadDays, ExpirationAlertPolicy.maxLeadDays);
      },
    );

    test(
      'Escenario: la preferencia guardada se recupera en una nueva '
      'instancia (simulando reabrir la app)',
      () async {
        final first = NotificationSettingsProvider();
        await first.setLeadDays(6);

        final second = NotificationSettingsProvider();
        await pumpEventQueue();

        expect(second.leadDays, 6);
      },
    );
  });
}
