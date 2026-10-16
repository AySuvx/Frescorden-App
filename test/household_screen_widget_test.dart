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
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_activity_log_repository.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';
import 'package:frescorden/presentation/screens/household_screen.dart';

import 'support/fake_repositories.dart';

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
  final now = DateTime(2026, 1, 1);
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
      provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
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
  });
}
