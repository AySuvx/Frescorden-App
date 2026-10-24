// test/presentation/screens/contact_screen_widget_test.dart
//
// Estabilidad visual de ContactScreen: ambas opciones de contacto
// renderizan. El tap real (_launchEmail) dispara url_launcher, un canal
// de plataforma real que no se mockea acá (mismo criterio que
// auth_repository_impl_test.dart con GoogleSignIn) — fuera de alcance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frescorden/presentation/screens/contact_screen.dart';

void main() {
  group('Estabilidad visual: ContactScreen', () {
    testWidgets(
      'Escenario: la pantalla muestra las dos opciones de contacto',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ContactScreen()),
        );

        expect(find.text('Contáctanos'), findsAtLeastNWidgets(1));
        expect(find.text('Reporta un problema'), findsOneWidget);
        expect(
          find.text('Envíanos un correo para cualquier consulta.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
