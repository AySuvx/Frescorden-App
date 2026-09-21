// Subtipos de DomainException para autenticación (cierra ADR-005 y el
// hallazgo S-05 del diagnóstico: login_screen.dart ya no captura
// FirebaseAuthException directamente — AuthRepositoryImpl la traduce a
// una de estas excepciones antes de que llegue a Presentation).

import 'domain_exception.dart';

/// Correo o contraseña incorrectos (agrupa los códigos de Firebase
/// 'wrong-password', 'invalid-credential' e 'invalid-email': no se
/// distingue cuál fue exactamente para no revelar si el correo existe).
class InvalidCredentialsException extends DomainException {
  const InvalidCredentialsException()
    : super('Correo o contraseña incorrectos.');
}

/// No existe ninguna cuenta registrada con ese correo.
class UserNotFoundException extends DomainException {
  const UserNotFoundException()
    : super('No existe una cuenta con ese correo electrónico.');
}

/// Ya existe una cuenta registrada con ese correo.
class EmailAlreadyInUseException extends DomainException {
  const EmailAlreadyInUseException()
    : super('Ya existe una cuenta con ese correo electrónico.');
}

/// La contraseña no cumple los requisitos mínimos de Firebase Auth.
class WeakPasswordException extends DomainException {
  const WeakPasswordException() : super('La contraseña es demasiado débil.');
}

/// Correo no verificado tras iniciar sesión — regla propia de la app (no
/// de Firebase), mismo mensaje que ya mostraba el AuthException original.
class UnverifiedEmailException extends DomainException {
  const UnverifiedEmailException()
    : super('Por favor, verifica tu correo electrónico para iniciar sesión.');
}

/// Cualquier otro FirebaseAuthException sin mapeo específico (red,
/// demasiados intentos, cuenta deshabilitada, etc.) — conserva el mensaje
/// original de Firebase como mejor alternativa a uno genérico.
class AuthOperationException extends DomainException {
  const AuthOperationException(super.message);
}
