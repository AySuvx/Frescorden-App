// lib/presentation/providers/auth_provider.dart
//
// Proveedor de estado para autenticación. Implementa ChangeNotifier
// (compatible con el Provider ya instalado en el proyecto).
//
// Las pantallas ya NO llaman a FirebaseAuth.instance / GoogleSignIn()
// directamente: delegan en este provider, que a su vez delega en
// IAuthRepository. Sigue el mismo patrón que ProductProvider: los métodos
// relanzan (`rethrow`) la excepción original para que la pantalla decida
// qué SnackBar mostrar, conservando los mensajes actuales.

import 'package:flutter/foundation.dart';
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
