// test/auth_exceptions_test.dart
//
// Cubre las subclases de DomainException para autenticación
// (lib/core/errors/auth_exceptions.dart): cada una debe traer el mensaje
// esperado y comportarse como DomainException (mismo mensaje en toString()).

import 'package:flutter_test/flutter_test.dart';

import 'package:frescorden/core/errors/auth_exceptions.dart';
import 'package:frescorden/core/errors/domain_exception.dart';

void main() {
  group('Excepciones de autenticación', () {
    test('InvalidCredentialsException trae el mensaje esperado', () {
      const exception = InvalidCredentialsException();

      expect(exception.message, 'Correo o contraseña incorrectos.');
      expect(exception.toString(), exception.message);
      expect(exception, isA<DomainException>());
    });

    test('UserNotFoundException trae el mensaje esperado', () {
      const exception = UserNotFoundException();

      expect(
        exception.message,
        'No existe una cuenta con ese correo electrónico.',
      );
      expect(exception, isA<DomainException>());
    });

    test('EmailAlreadyInUseException trae el mensaje esperado', () {
      const exception = EmailAlreadyInUseException();

      expect(
        exception.message,
        'Ya existe una cuenta con ese correo electrónico.',
      );
      expect(exception, isA<DomainException>());
    });

    test('WeakPasswordException trae el mensaje esperado', () {
      const exception = WeakPasswordException();

      expect(exception.message, 'La contraseña es demasiado débil.');
      expect(exception, isA<DomainException>());
    });

    test('UnverifiedEmailException trae el mensaje esperado', () {
      const exception = UnverifiedEmailException();

      expect(
        exception.message,
        'Por favor, verifica tu correo electrónico para iniciar sesión.',
      );
      expect(exception, isA<DomainException>());
    });

    test('AuthOperationException conserva el mensaje recibido', () {
      const exception = AuthOperationException('mensaje original de Firebase');

      expect(exception.message, 'mensaje original de Firebase');
      expect(exception, isA<DomainException>());
    });
  });
}
