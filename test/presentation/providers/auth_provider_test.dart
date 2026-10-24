// test/presentation/providers/auth_provider_test.dart
//
// BDD de AuthProvider.isAdmin: único punto de verdad para el acceso al
// Panel Administrativo — por kAdminUid o por un correo de kAdminEmails
// (ver app_config.dart). FakeAuthRepository en test/support.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/config/app_config.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como app, quiero saber si el usuario '
      'autenticado es administrador', () {
    test('Escenario: sin sesión iniciada, no es admin', () {
      final provider = AuthProvider(FakeAuthRepository());

      expect(provider.isAdmin, isFalse);
    });

    test('Escenario: el UID admin principal (kAdminUid) es admin', () {
      final provider = AuthProvider(
        FakeAuthRepository()
          ..currentUser = const AppUser(uid: kAdminUid, emailVerified: true),
      );

      expect(provider.isAdmin, isTrue);
    });

    test(
      'Escenario: un correo de kAdminEmails es admin aunque su UID no '
      'sea kAdminUid',
      () {
        final provider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(
              uid: 'uid-cualquiera',
              email: 'familiaotalora98@gmail.com',
              emailVerified: true,
            ),
        );

        expect(provider.isAdmin, isTrue);
      },
    );

    test(
      'Escenario: la comparación de correo ignora mayúsculas/minúsculas y '
      'espacios en blanco',
      () {
        final provider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(
              uid: 'uid-cualquiera',
              email: ' FamiliaOtalora98@Gmail.com ',
              emailVerified: true,
            ),
        );

        expect(provider.isAdmin, isTrue);
      },
    );

    test(
      'Escenario: un usuario normal (ni UID ni correo admin) no es admin',
      () {
        final provider = AuthProvider(
          FakeAuthRepository()
            ..currentUser = const AppUser(
              uid: 'uid-normal',
              email: 'nadie@example.com',
              emailVerified: true,
            ),
        );

        expect(provider.isAdmin, isFalse);
      },
    );
  });
}
