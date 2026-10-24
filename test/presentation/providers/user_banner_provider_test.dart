// test/presentation/providers/user_banner_provider_test.dart
//
// BDD de UserBannerProvider: persiste el banner elegido para el
// encabezado del menú (ver InicioScreen._buildDrawerHeader).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frescorden/presentation/providers/user_banner_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Historia de Usuario: Como usuario, quiero personalizar el banner '
      'del menú con una foto', () {
    test(
      'Escenario: sin preferencia guardada, no hay banner elegido (se usa '
      'el degradado por defecto)',
      () {
        final provider = UserBannerProvider();

        expect(provider.selectedBannerAsset, isNull);
        expect(provider.selectedBannerName, isNull);
      },
    );

    test(
      'Escenario: elegir una foto de la galería la aplica de inmediato',
      () async {
        final provider = UserBannerProvider();

        await provider.setBanner('Perritos.jpg');

        expect(provider.selectedBannerName, 'Perritos.jpg');
        expect(
          provider.selectedBannerAsset,
          'assets/banners-usuario/Perritos.jpg',
        );
      },
    );

    test(
      'Escenario: volver a "Predeterminado" (null) quita la foto elegida',
      () async {
        final provider = UserBannerProvider();
        await provider.setBanner('Gato.jpg');

        await provider.setBanner(null);

        expect(provider.selectedBannerName, isNull);
        expect(provider.selectedBannerAsset, isNull);
      },
    );

    test(
      'Escenario: la foto elegida se recupera en una nueva instancia '
      '(simulando reabrir la app)',
      () async {
        final first = UserBannerProvider();
        await first.setBanner('Oveja.jpg');

        final second = UserBannerProvider();
        await pumpEventQueue();

        expect(second.selectedBannerName, 'Oveja.jpg');
      },
    );

    test(
      'Escenario: un valor guardado que ya no está en la galería curada '
      'se ignora (vuelve al degradado)',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_banner': 'Foto-que-ya-no-existe.jpg',
        });
        final provider = UserBannerProvider();
        await pumpEventQueue();

        expect(provider.selectedBannerName, isNull);
      },
    );
  });
}
