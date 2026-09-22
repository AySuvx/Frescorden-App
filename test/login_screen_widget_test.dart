// test/login_screen_widget_test.dart
//
// Widget tests de LoginScreen: cubren las validaciones locales de
// submitEmailPassword/resetPassword (campos vacíos, criterios de
// contraseña) y el manejo de errores de dominio (DomainException) sin
// tocar Firebase — usando AuthProvider real con FakeAuthRepository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/core/errors/auth_exceptions.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/screens/login_screen.dart';

import 'support/fake_repositories.dart';

// El MultiProvider envuelve el MaterialApp (no solo `home`): las rutas que
// LoginScreen empuja con Navigator.pushReplacement (InicioScreen) son
// hermanas de `home` dentro del mismo Navigator, así que un provider
// declarado solo alrededor de `home` no las alcanza.
Widget _wrap(AuthProvider authProvider, {ProductProvider? productProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ProductProvider>.value(
        value: productProvider ?? ProductProvider(FakeProductRepository()),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('Estabilidad y validaciones: LoginScreen', () {
    late FakeAuthRepository repo;
    late AuthProvider authProvider;

    setUp(() {
      repo = FakeAuthRepository();
      authProvider = AuthProvider(repo);
    });

    testWidgets(
      'Escenario: enviar el formulario de login con campos vacíos muestra '
      'un aviso y no llama al repositorio',
      (tester) async {
        await tester.pumpWidget(_wrap(authProvider));

        await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
        await tester.pump();

        expect(find.text('Ingresa tu correo y contraseña.'), findsOneWidget);
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: registrarse con una contraseña que no cumple los '
      'requisitos muestra un aviso y no llama al repositorio',
      (tester) async {
        await tester.pumpWidget(_wrap(authProvider));

        // Cambiar a modo registro — fuera del viewport por defecto de
        // flutter_test (800x600), hay que scrollear hasta el widget.
        final registrarseLink = find.text('¿No tienes cuenta? Regístrate aquí');
        await tester.ensureVisible(registrarseLink);
        await tester.pump();
        await tester.tap(registrarseLink);
        await tester.pump();

        await tester.enterText(
          find.byType(TextField).at(0),
          'nueva@correo.com',
        );
        await tester.enterText(find.byType(TextField).at(1), 'corta');

        final registrarseButton = find.widgetWithText(
          ElevatedButton,
          'Registrarse',
        );
        await tester.ensureVisible(registrarseButton);
        await tester.pump();
        await tester.tap(registrarseButton);
        await tester.pump();

        expect(
          find.text('La contraseña no cumple con los requisitos.'),
          findsOneWidget,
        );
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: login con credenciales inválidas muestra el mensaje de '
      'la DomainException sin navegar',
      (tester) async {
        repo.signInError = const InvalidCredentialsException();
        await tester.pumpWidget(_wrap(authProvider));

        await tester.enterText(
          find.byType(TextField).at(0),
          'correo@ejemplo.com',
        );
        await tester.enterText(find.byType(TextField).at(1), 'Passw0rd!');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
        await tester.pump();

        expect(repo.calls, ['signInWithEmail']);
        expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: login exitoso llama al repositorio y navega a InicioScreen',
      (tester) async {
        await tester.pumpWidget(_wrap(authProvider));

        await tester.enterText(
          find.byType(TextField).at(0),
          'correo@ejemplo.com',
        );
        await tester.enterText(find.byType(TextField).at(1), 'Passw0rd!');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
        // pushReplacement anima la salida de LoginScreen — pumpAndSettle
        // espera a que termine la transición antes de verificar que ya
        // no está en el árbol.
        await tester.pumpAndSettle();

        expect(repo.calls, ['signInWithEmail']);
        expect(find.byType(LoginScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: Google Sign-In con error de dominio muestra el mensaje',
      (tester) async {
        repo.signInWithGoogleError = const AuthOperationException(
          'Fallo de red con Google.',
        );
        await tester.pumpWidget(_wrap(authProvider));

        final googleButton = find.text('Ingresar con Google');
        await tester.ensureVisible(googleButton);
        await tester.pump();
        await tester.tap(googleButton);
        await tester.pump();

        expect(repo.calls, ['signInWithGoogle']);
        expect(find.text('Fallo de red con Google.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: restablecer contraseña con el correo vacío muestra un '
      'aviso y no llama al repositorio',
      (tester) async {
        await tester.pumpWidget(_wrap(authProvider));

        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pump();

        expect(
          find.text('Por favor, ingresa tu correo electrónico.'),
          findsOneWidget,
        );
        expect(repo.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: restablecer contraseña con correo válido llama al '
      'repositorio y muestra la confirmación',
      (tester) async {
        await tester.pumpWidget(_wrap(authProvider));

        await tester.enterText(
          find.byType(TextField).at(0),
          'correo@ejemplo.com',
        );
        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pump();

        expect(repo.calls, ['sendPasswordReset']);
        expect(
          find.text('Se ha enviado un correo para restablecer tu contraseña.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
