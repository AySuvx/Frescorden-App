import '../entities/app_user.dart';

/// Excepción de dominio para casos que no vienen directamente de Firebase
/// (p. ej. correo no verificado), para que la capa de presentación pueda
/// mostrar el mismo mensaje sin conocer el tipo de excepción original.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

abstract interface class IAuthRepository {
  /// Emite el usuario autenticado actual, o `null` si no hay sesión.
  Stream<AppUser?> authStateChanges();

  /// Usuario autenticado actual (síncrono), o `null` si no hay sesión.
  AppUser? get currentUser;

  /// Inicia sesión con correo y contraseña.
  /// Lanza [Exception] si el correo no ha sido verificado (y cierra la
  /// sesión recién iniciada, igual que el comportamiento original).
  Future<void> signInWithEmail(String email, String password);

  /// Registra una cuenta nueva con correo y contraseña, envía el correo
  /// de verificación y cierra la sesión (el usuario debe verificar antes
  /// de poder iniciar sesión).
  Future<void> registerWithEmail(String email, String password);

  /// Inicia sesión con Google. Cierra cualquier sesión de Google previa
  /// primero, para forzar el selector de cuenta.
  Future<void> signInWithGoogle();

  /// Envía un correo para restablecer la contraseña.
  Future<void> sendPasswordReset(String email);

  /// Cierra la sesión actual (Firebase y Google).
  Future<void> signOut();

  /// Elimina el documento del usuario en Firestore y la cuenta de Auth.
  Future<void> deleteAccount();
}
