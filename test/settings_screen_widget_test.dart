// test/settings_screen_widget_test.dart
//
// Widget tests de estabilidad visual de SettingsScreen: tema, color de
// acento, antelación de notificaciones. Usa SharedPreferences.setMockInitialValues
// (ThemeProvider/NotificationSettingsProvider) y un mock del canal de
// permission_handler (ver _mockNotificationPermissionGranted) — sin este
// último, `Permission.notification.status` en initState lanza
// MissingPluginException al no haber una implementación nativa en el
// entorno de test.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frescorden/config/theme/theme_provider.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/notification_settings_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/screens/settings_screen.dart';

import 'support/fake_repositories.dart';

/// Responde `granted` (1) a cualquier `checkPermissionStatus` del canal de
/// permission_handler — evita que `_requestNotificationPermission` (ver
/// SettingsScreen.initState → _loadPreferences) dispare una excepción no
/// controlada por falta de implementación nativa en el test.
void _mockNotificationPermissionGranted() {
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'checkPermissionStatus') return 1; // granted
    return null;
  });
}

Widget _wrap({
  required ThemeProvider themeProvider,
  required NotificationSettingsProvider notificationSettings,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<NotificationSettingsProvider>.value(
          value: notificationSettings,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(FakeAuthRepository()),
        ),
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(FakeProductRepository()),
        ),
      ],
      child: const SettingsScreen(),
    ),
  );
}

void main() {
  group('Estabilidad visual: SettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _mockNotificationPermissionGranted();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        null,
      );
    });

    testWidgets(
      'Escenario: la pantalla renderiza sus controles principales sin '
      'excepciones',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Tema'), findsOneWidget);
        expect(find.text('Color de acento'), findsOneWidget);
        expect(find.text('Avisarme con antelación'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el color de acento actual aparece marcado con un check',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Acotado al Wrap de colores: el SegmentedButton de Tema también
        // dibuja su propio ícono de check incorporado para el segmento
        // seleccionado (mismo IconData).
        expect(
          find.descendant(
            of: find.byType(Wrap),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Escenario: tocar un color de acento distinto lo aplica',
      (tester) async {
        final themeProvider = ThemeProvider();
        await tester.pumpWidget(
          _wrap(
            themeProvider: themeProvider,
            notificationSettings: NotificationSettingsProvider(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byTooltip('Azul'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(themeProvider.seedColor.toARGB32(), const Color(0xFF1565C0).toARGB32());
      },
    );

    testWidgets(
      'Escenario: mover el slider de antelación actualiza el subtítulo',
      (tester) async {
        final notificationSettings = NotificationSettingsProvider();
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: notificationSettings,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('3 días antes de que venza'), findsOneWidget);

        await tester.drag(find.byType(Slider), const Offset(200, 0));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('3 días antes de que venza'), findsNothing);
      },
    );
  });
}
