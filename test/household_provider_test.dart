// test/household_provider_test.dart
//
// BDD (Given/When/Then) de HouseholdProvider, con FakeHouseholdRepository
// (test/support/fake_repositories.dart) en vez de Firestore.
//
// Nota (Fase 6, Módulo 3): el brief de este módulo no dio un escenario
// puntual para HouseholdProvider (a diferencia de ProductProvider/
// ShoppingProvider/RecipeProvider) — se cubren las reglas de permisos de
// removeMember/leaveHousehold, que son la lógica de negocio real más
// valiosa y frágil del provider (ver comentarios del propio
// household_provider.dart junto a cada método).
//
// setUid() es intencionalmente público "para tests que quieran simular el
// cambio sin pasar por un Stream real" (ver su propio doc comment) — se usa
// acá en vez de construir un Stream<AppUser?> real.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/presentation/providers/household_provider.dart';

import 'support/fake_repositories.dart';

Household _household({
  required String createdBy,
  required List<String> members,
}) {
  final now = DateTime(2026, 1, 1);
  return Household(
    id: 'hogar-1',
    name: 'Mi Hogar',
    createdBy: createdBy,
    members: members,
    inviteCode: 'ABC123',
    codeExpiresAt: now.add(const Duration(hours: 24)),
    createdAt: now,
  );
}

/// Deja el provider con un hogar activo y su lista de miembros lista para
/// probar removeMember/leaveHousehold, simulando la cadena reactiva real
/// (uid → activeHouseholdId → household) sin un `Stream<AppUser?>` real.
Future<HouseholdProvider> _providerWithHousehold(
  FakeHouseholdRepository repo,
  Household household,
  String currentUid,
) async {
  final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
  provider.setUid(currentUid);
  repo.emitActiveId(household.id);
  await pumpEventQueue();
  repo.emitHousehold(household);
  await pumpEventQueue();
  return provider;
}

void main() {
  group('Historia de Usuario: Como administrador de un hogar, quiero poder '
      'gestionar quién es miembro', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: el administrador expulsa a otro miembro exitosamente',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando expulso a otro miembro
        await provider.removeMember('miembro-uid');

        // Entonces la operación se delega al repositorio sin excepción
        expect(repo.removedMemberUids, ['miembro-uid']);
      },
    );

    test(
      'Escenario: un miembro regular NO puede expulsar a otro miembro',
      () async {
        // Dado un hogar donde YO soy un miembro regular (no el admin)
        final hogar = _household(
          createdBy: 'admin-uid',
          members: ['admin-uid', 'miembro-uid', 'otro-miembro-uid'],
        );
        final provider = await _providerWithHousehold(repo, hogar, 'miembro-uid');
        addTearDown(provider.dispose);

        // Cuando intento expulsar a otro miembro
        // Entonces se lanza HouseholdException y nunca se llega al repositorio
        await expectLater(
          () => provider.removeMember('otro-miembro-uid'),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );

    test(
      'Escenario: el administrador no puede expulsarse a sí mismo',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando intento "expulsarme" a mí mismo
        // Entonces se lanza HouseholdException
        await expectLater(
          () => provider.removeMember('admin-uid'),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como miembro de un hogar, quiero poder '
      'salir de él sin dejarlo huérfano', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: un miembro regular sale del hogar exitosamente',
      () async {
        // Dado un hogar donde YO soy un miembro regular
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'miembro-uid');
        addTearDown(provider.dispose);

        // Cuando salgo del hogar
        await provider.leaveHousehold();

        // Entonces me quito de members y se limpia mi activeHouseholdId
        expect(repo.removedMemberUids, ['miembro-uid']);
        expect(repo.clearedActiveHouseholdUids, ['miembro-uid']);
      },
    );

    test(
      'Escenario: el administrador NO puede salir de su propio hogar',
      () async {
        // Dado un hogar donde YO soy el administrador
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid', 'miembro-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'admin-uid');
        addTearDown(provider.dispose);

        // Cuando intento salir del hogar
        // Entonces se lanza HouseholdException (debe expulsar a los demás
        // miembros primero)
        await expectLater(
          () => provider.leaveHousehold(),
          throwsA(isA<HouseholdException>()),
        );
        expect(repo.removedMemberUids, isEmpty);
        expect(repo.clearedActiveHouseholdUids, isEmpty);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero que mi sesión determine '
      'mi hogar activo automáticamente', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: un usuario recién autenticado sin hogar previo dispara '
      'el bootstrap de un hogar personal',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        provider.setUid('nuevo-uid');
        repo.emitActiveId(null);
        await pumpEventQueue();

        expect(repo.bootstrappedUids, ['nuevo-uid']);
        expect(provider.hasHousehold, isFalse);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: recibir el mismo activeHouseholdId dos veces no dispara '
      'un segundo bootstrap ni relee el hogar',
      () async {
        final hogar = _household(createdBy: 'uid-1', members: ['uid-1']);
        final provider = await _providerWithHousehold(repo, hogar, 'uid-1');
        addTearDown(provider.dispose);

        repo.emitActiveId(hogar.id);
        await pumpEventQueue();

        expect(provider.household, hogar);
        expect(repo.bootstrappedUids, isEmpty);
      },
    );

    test(
      'Escenario: cerrar sesión (uid null) limpia el hogar activo',
      () async {
        final hogar = _household(createdBy: 'uid-1', members: ['uid-1']);
        final provider = await _providerWithHousehold(repo, hogar, 'uid-1');
        addTearDown(provider.dispose);

        provider.setUid(null);

        expect(provider.hasHousehold, isFalse);
        expect(provider.household, isNull);
        expect(provider.isLoading, isFalse);
        expect(provider.currentUid, isNull);
      },
    );

    test(
      'Escenario: si watchActiveHouseholdId falla, se expone el error y '
      'deja de cargar',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        provider.setUid('uid-1');
        repo.emitActiveIdError(Exception('sin conexión'));
        await pumpEventQueue();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: si watchHousehold falla, se expone el error y deja de '
      'cargar',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        provider.setUid('uid-1');
        repo.emitActiveId('hogar-1');
        await pumpEventQueue();
        repo.emitHouseholdError(Exception('permiso denegado'));
        await pumpEventQueue();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: si me expulsaron del hogar (ya no soy miembro), se limpia '
      'mi activeHouseholdId automáticamente',
      () async {
        final hogar = _household(createdBy: 'admin-uid', members: ['admin-uid']);
        final provider = await _providerWithHousehold(repo, hogar, 'expulsado-uid');
        addTearDown(provider.dispose);

        expect(repo.clearedActiveHouseholdUids, ['expulsado-uid']);
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero crear o unirme a un '
      'hogar', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: crear un hogar sin sesión iniciada lanza HouseholdException',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        await expectLater(
          () => provider.createHousehold('Mi Hogar'),
          throwsA(isA<HouseholdException>()),
        );
      },
    );

    test(
      'Escenario: si el repositorio falla al crear el hogar, se expone el '
      'error y se relanza',
      () async {
        repo.createHouseholdError = Exception('nombre duplicado');
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await pumpEventQueue();

        await expectLater(
          () => provider.createHousehold('Mi Hogar'),
          throwsException,
        );
        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: unirse a un hogar sin sesión iniciada lanza HouseholdException',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        await expectLater(
          () => provider.joinHousehold('ABC123'),
          throwsA(isA<HouseholdException>()),
        );
      },
    );

    test(
      'Escenario: si el código de invitación es inválido, se expone el '
      'error y se relanza',
      () async {
        repo.joinHouseholdError = Exception('código inválido');
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);
        provider.setUid('uid-1');
        repo.emitActiveId(null);
        await pumpEventQueue();

        await expectLater(
          () => provider.joinHousehold('XXXXXX'),
          throwsException,
        );
        expect(provider.error, isNotNull);
      },
    );
  });

  group('Historia de Usuario: Como miembro de un hogar, quiero renovar el '
      'código de invitación', () {
    late FakeHouseholdRepository repo;

    setUp(() => repo = FakeHouseholdRepository());
    tearDown(() => repo.dispose());

    test(
      'Escenario: sin hogar activo, generar un código nuevo lanza '
      'HouseholdException',
      () async {
        final provider = HouseholdProvider(repo, const Stream<AppUser?>.empty());
        addTearDown(provider.dispose);

        await expectLater(
          () => provider.generateNewInviteCode(),
          throwsA(isA<HouseholdException>()),
        );
      },
    );

    test(
      'Escenario: con hogar activo, se devuelve el código nuevo generado',
      () async {
        final hogar = _household(createdBy: 'uid-1', members: ['uid-1']);
        final provider = await _providerWithHousehold(repo, hogar, 'uid-1');
        addTearDown(provider.dispose);
        repo.inviteCodeToReturn = 'NUEVO1';

        final code = await provider.generateNewInviteCode();

        expect(code, 'NUEVO1');
      },
    );

    test(
      'Escenario: si el repositorio falla al generar el código, se expone '
      'el error y se relanza',
      () async {
        final hogar = _household(createdBy: 'uid-1', members: ['uid-1']);
        final provider = await _providerWithHousehold(repo, hogar, 'uid-1');
        addTearDown(provider.dispose);
        repo.generateInviteCodeError = Exception('fallo de red');

        await expectLater(
          () => provider.generateNewInviteCode(),
          throwsException,
        );
        expect(provider.error, isNotNull);
      },
    );
  });
}
