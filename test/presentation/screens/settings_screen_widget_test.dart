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
import 'package:frescorden/presentation/screens/login_screen.dart';
import 'package:frescorden/presentation/screens/settings_screen.dart';

import '../../support/fake_repositories.dart';

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
  AuthProvider? authProvider,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<NotificationSettingsProvider>.value(
          value: notificationSettings,
        ),
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider ?? AuthProvider(FakeAuthRepository()),
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

    testWidgets(
      'Escenario: elegir un modo de tema distinto lo aplica',
      (tester) async {
        final themeProvider = ThemeProvider();
        await tester.pumpWidget(
          _wrap(
            themeProvider: themeProvider,
            notificationSettings: NotificationSettingsProvider(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Oscuro'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(themeProvider.themeMode, ThemeMode.dark);
      },
    );

    testWidgets(
      'Escenario: el selector de idioma permite cambiar entre Español e '
      'Inglés',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Idioma actual: Español'), findsOneWidget);

        await tester.tap(find.text('Idioma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inglés'));
        await tester.pumpAndSettle();

        expect(find.text('Idioma actual: Inglés'), findsOneWidget);

        await tester.tap(find.text('Idioma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();

        expect(find.text('Idioma actual: Español'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cancelar el diálogo de "Eliminar cuenta" no elimina '
      'nada',
      (tester) async {
        final repo = FakeAuthRepository();
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
            authProvider: AuthProvider(repo),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Eliminar cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(repo.calls, isNot(contains('deleteAccount')));
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: confirmar "Eliminar cuenta" la elimina y navega al '
      'login',
      (tester) async {
        final repo = FakeAuthRepository();
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
            authProvider: AuthProvider(repo),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Eliminar cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(repo.calls, contains('deleteAccount'));
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si falla la eliminación de la cuenta, se informa el '
      'error y no se navega',
      (tester) async {
        final repo = FakeAuthRepository()
          ..deleteAccountError = Exception('sin conexión');
        await tester.pumpWidget(
          _wrap(
            themeProvider: ThemeProvider(),
            notificationSettings: NotificationSettingsProvider(),
            authProvider: AuthProvider(repo),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Eliminar cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Error al eliminar la cuenta. Intenta nuevamente.'),
          findsOneWidget,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
