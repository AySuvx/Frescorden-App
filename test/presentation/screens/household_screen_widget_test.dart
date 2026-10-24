// test/household_screen_widget_test.dart
//
// Widget tests de estabilidad visual de HouseholdScreen: renderiza sin
// excepciones en sus estados reales (sin hogar, con hogar propio, con
// hogar ajeno donde no soy admin) usando HouseholdProvider real con
// FakeHouseholdRepository/FakeActivityLogRepository en vez de Firestore.
//
// Nota: `pumpEventQueue()` (usado en household_provider_test.dart, un
// test NO widget) no sirve acá — dentro de `testWidgets` el binding corre
// en una zona FakeAsync, y los Timer internos de pumpEventQueue nunca
// avanzan solos (deja el test colgado para siempre, no solo lento). El
// patrón correcto es: montar el widget primero, y usar
// `await tester.pump()` después de cada evento de stream para que la
// entrega del broadcast se resuelva dentro del ciclo de frame normal.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/activity_log_entry.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_activity_log_repository.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';
import 'package:frescorden/presentation/screens/household_screen.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';

/// El canal de clipboard no tiene una implementación por defecto en el
/// entorno de test — sin este mock, `Clipboard.setData` (ver
/// HouseholdScreen._copyCode) queda esperando para siempre y el SnackBar
/// de confirmación nunca llega a mostrarse.
void _mockClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') return null;
    return null;
  });
}

Widget _wrap(HouseholdProvider provider, IActivityLogRepository activityLog) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<HouseholdProvider>.value(value: provider),
        Provider<IActivityLogRepository>.value(value: activityLog),
      ],
      child: const HouseholdScreen(),
    ),
  );
}

Household _household({
  required String createdBy,
  required List<String> members,
}) {
  // codeExpiresAt se calcula desde el reloj real (no desde una fecha fija
  // del pasado): un Household "no expirado" debe seguir siéndolo sin
  // importar cuándo se corra la prueba.
  final now = DateTime.now();
  return Household(
    id: 'hogar-1',
    name: 'Casa de los Gómez',
    createdBy: createdBy,
    members: members,
    memberEmails: {for (final m in members) m: '$m@frescorden.app'},
    inviteCode: 'ABC123',
    codeExpiresAt: now.add(const Duration(hours: 24)),
    createdAt: now,
  );
}

void main() {
  group('Estabilidad visual: HouseholdScreen', () {
    late FakeHouseholdRepository repo;
    late FakeActivityLogRepository activityLog;
    late HouseholdProvider provider;

    setUp(() {
      repo = FakeHouseholdRepository();
      activityLog = FakeActivityLogRepository();
      // FakeHouseholdAnalyticsService inyectado: sin esto, cualquier
      // llamado que registre un evento (joinHousehold, createHousehold)
      // dispara el singleton real de Firebase Analytics la primera vez
      // que se usa, lo que lanza una excepción en el entorno de test.
      provider = HouseholdProvider(
        repo,
        const Stream<AppUser?>.empty(),
        FakeHouseholdAnalyticsService(),
      );
      _mockClipboard();
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
      activityLog.dispose();
    });

    testWidgets(
      'Escenario: sin hogar activo, se muestra el estado vacío sin '
      'excepciones',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));

        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await tester.pump();

        expect(
          find.textContaining('Todavía no tienes un hogar activo'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: como administrador de mi hogar, veo el botón de '
      'renombrar y NO veo "Salir del Hogar"',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));

        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'otro-uid']),
        );
        await tester.pump();

        expect(find.text('Casa de los Gómez'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.text('Salir del Hogar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: como miembro regular, veo "Salir del Hogar" y puedo '
      'renombrar el hogar',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));

        provider.setUid('miembro-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']),
        );
        await tester.pump();

        expect(find.text('Salir del Hogar'), findsOneWidget);

        // Cuando toco el ícono de renombrar y guardo un nombre nuevo (el
        // finder se acota al diálogo: la pantalla de fondo también tiene
        // un TextField, el de "Unirse a un Hogar"). Se evita pumpAndSettle
        // (cualquier animación sin fin la deja esperando para siempre) a
        // favor de pumps con duración acotada, igual que
        // productos_screen_widget_test.dart.
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Casa Nueva',
        );
        await tester.tap(find.text('Guardar'));
        await tester.pump(const Duration(milliseconds: 300));

        // Entonces se llamó al repositorio con el nombre nuevo
        expect(repo.renamedHouseholdNames, ['Casa Nueva']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con el código de invitación expirado, se ofrece '
      'generar uno nuevo',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));

        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        final now = DateTime.now();
        repo.emitHousehold(
          Household(
            id: 'hogar-1',
            name: 'Casa de los Gómez',
            createdBy: 'admin-uid',
            members: ['admin-uid'],
            inviteCode: 'ABC123',
            codeExpiresAt: now.subtract(const Duration(hours: 1)),
            createdAt: now,
          ),
        );
        await tester.pump();

        expect(find.text('Generar código nuevo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: copiar el código de invitación muestra la confirmación',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Código copiado: ABC123'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: renovar el código muestra el código nuevo generado',
      (tester) async {
        repo.inviteCodeToReturn = 'ZZZ999';
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.text('Renovar código'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Código nuevo generado: ZZZ999'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si falla renovar el código, se informa el mensaje de '
      'la excepción de dominio',
      (tester) async {
        repo.generateInviteCodeError = const HouseholdException('No hay un hogar activo.');
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.text('Renovar código'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('No hay un hogar activo.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si falla renovar el código con un error genérico, se '
      'informa el mensaje por defecto',
      (tester) async {
        repo.generateInviteCodeError = Exception('sin conexión');
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.text('Renovar código'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('No se pudo generar un código nuevo. Intenta de nuevo.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cancelar la expulsión de un miembro no lo elimina',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'otro-uid']),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.person_remove));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(repo.removedMemberUids, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: confirmar la expulsión de un miembro lo elimina y '
      'muestra la confirmación',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'otro-uid']),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.person_remove));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expulsar'));
        await tester.pumpAndSettle();

        expect(repo.removedMemberUids, ['otro-uid']);
        expect(find.text('Miembro expulsado.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si falla expulsar a un miembro, se informa el error',
      (tester) async {
        repo.removeMemberError = Exception('sin permisos');
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'otro-uid']),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.person_remove));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expulsar'));
        await tester.pumpAndSettle();

        expect(find.text('No se pudo expulsar al miembro.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cancelar "Salir del Hogar" no sale del hogar',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('miembro-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']),
        );
        await tester.pump();

        await tester.tap(find.text('Salir del Hogar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(repo.removedMemberUids, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: confirmar "Salir del Hogar" sale y muestra la '
      'confirmación',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('miembro-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(
          _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']),
        );
        await tester.pump();

        await tester.tap(find.text('Salir del Hogar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salir'));
        await tester.pumpAndSettle();

        expect(repo.removedMemberUids, ['miembro-uid']);
        expect(repo.clearedActiveHouseholdUids, ['miembro-uid']);
        expect(find.text('Saliste del hogar.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: un código de menos de 6 caracteres no intenta unirse',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'ABC');
        await tester.tap(find.text('Unirse'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('El código debe tener 6 caracteres.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: unirse a un hogar muestra la vista previa y, al '
      'confirmar, se une de verdad',
      (tester) async {
        repo.previewHouseholdResult = _household(
          createdBy: 'otro-admin',
          members: ['otro-admin', 'alguien-mas'],
        );
        repo.joinHouseholdResult = repo.previewHouseholdResult;
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'F83K92');
        await tester.tap(find.text('Unirse'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('¿Es este tu hogar?'), findsOneWidget);
        expect(find.textContaining('2 miembros'), findsOneWidget);

        await tester.tap(find.text('Sí, unirme'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Te uniste al hogar correctamente.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cancelar la vista previa de "¿Es este tu hogar?" no une '
      'al usuario',
      (tester) async {
        repo.previewHouseholdResult = _household(
          createdBy: 'otro-admin',
          members: ['otro-admin'],
        );
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'F83K92');
        await tester.tap(find.text('Unirse'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Cancelar'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Te uniste al hogar correctamente.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: si el código no existe, se informa el mensaje de la '
      'excepción de dominio',
      (tester) async {
        repo.previewHouseholdError =
            const HouseholdException('Ese código no existe o ya expiró.');
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'F83K92');
        await tester.tap(find.text('Unirse'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Ese código no existe o ya expiró.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el historial de actividad muestra el spinner antes del '
      'primer snapshot, y el estado vacío si llega una lista vacía',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.text('Historial de Actividad'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        activityLog.emitActivity(const []);
        await tester.pump();

        expect(
          find.text('Todavía no hay actividad registrada.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el historial de actividad muestra cada entrada con su '
      'ícono y hora',
      (tester) async {
        await tester.pumpWidget(_wrap(provider, activityLog));
        provider.setUid('admin-uid');
        repo.emitActiveId('hogar-1');
        await tester.pump();
        repo.emitHousehold(_household(createdBy: 'admin-uid', members: ['admin-uid']));
        await tester.pump();

        await tester.tap(find.text('Historial de Actividad'));
        await tester.pump(const Duration(milliseconds: 300));

        activityLog.emitActivity([
          ActivityLogEntry(
            productName: 'Leche',
            action: ActivityAction.consumido,
            userEmail: 'ana@frescorden.app',
            timestamp: DateTime.now(),
          ),
          ActivityLogEntry(
            productName: 'Tomate',
            action: ActivityAction.desperdiciado,
            userEmail: null,
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ]);
        await tester.pump();

        expect(find.text('Consumido: Leche'), findsOneWidget);
        expect(find.text('ana@frescorden.app'), findsOneWidget);
        expect(find.text('Desperdiciado: Tomate'), findsOneWidget);
        expect(find.text('Miembro del hogar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
