// Proveedor de estado para autenticación. Las pantallas delegan en este
// provider, que a su vez delega en IAuthRepository — nunca llaman a
// FirebaseAuth.instance / GoogleSignIn() directamente. Los métodos
// relanzan (`rethrow`) la excepción original para que la pantalla decida
// qué SnackBar mostrar.

import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final IAuthRepository _repository;

  AuthProvider(this._repository);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Stream de estado de autenticación, usado por main.dart para decidir
  /// entre LoginScreen e InicioScreen.
  Stream<AppUser?> get authStateChanges => _repository.authStateChanges();

  AppUser? get currentUser => _repository.currentUser;

  /// Único punto de verdad para "es el admin" (antes duplicado inline con
  /// `== kAdminUid` en admin_dashboard_screen.dart e inicio_screen.dart).
  /// Sigue controlando el Panel Administrativo — eso NO se abre durante el
  /// piloto, solo la IA (ver canUseLiveAi).
  bool get isAdmin => currentUser?.uid == kAdminUid;

  /// Punto de verdad para "puede usar la IA en vivo ahora" (asistente,
  /// receta con IA, reconocimiento de producto): el admin siempre puede, y
  /// mientras kAiPilotModeEnabled esté en true (piloto de Validación con
  /// usuarios) cualquier usuario autenticado también. Fuera del piloto,
  /// vuelve a ser solo el admin — ver AiComingSoonCard / ADR-004.
  bool get canUseLiveAi => isAdmin || kAiPilotModeEnabled;

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) {
    return _run(() => _repository.signInWithEmail(email, password));
  }

  Future<void> registerWithEmail(String email, String password) {
    return _run(() => _repository.registerWithEmail(email, password));
  }

  Future<void> signInWithGoogle() {
    return _run(() => _repository.signInWithGoogle());
  }

  Future<void> sendPasswordReset(String email) {
    return _run(() => _repository.sendPasswordReset(email));
  }

  Future<void> signOut() {
    return _run(() => _repository.signOut());
  }

  Future<void> deleteAccount() {
    return _run(() => _repository.deleteAccount());
  }
}
