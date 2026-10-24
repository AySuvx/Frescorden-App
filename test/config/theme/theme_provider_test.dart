// test/config/theme/theme_provider_test.dart
//
// BDD de ThemeProvider: persiste el ThemeMode y el color de acento (seed
// color de Material3) elegidos en Ajustes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frescorden/config/theme/app_colors.dart';
import 'package:frescorden/config/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Historia de Usuario: Como usuario, quiero elegir un color de '
      'acento para la app', () {
    test(
      'Escenario: sin preferencia guardada, el acento por defecto es el '
      'verde de marca',
      () {
        final provider = ThemeProvider();

        expect(provider.seedColor.toARGB32(), AppColors.primary.toARGB32());
      },
    );

    test('Escenario: elegir un color de acento lo aplica de inmediato', () async {
      final provider = ThemeProvider();
      const azul = Color(0xFF1565C0);

      await provider.setSeedColor(azul);

      expect(provider.seedColor.toARGB32(), azul.toARGB32());
    });

    test(
      'Escenario: el color de acento elegido se recupera en una nueva '
      'instancia (simulando reabrir la app)',
      () async {
        final first = ThemeProvider();
        const morado = Color(0xFF6A1B9A);
        await first.setSeedColor(morado);

        final second = ThemeProvider();
        await pumpEventQueue();

        expect(second.seedColor.toARGB32(), morado.toARGB32());
      },
    );
  });
}
