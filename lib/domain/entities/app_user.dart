// lib/domain/entities/app_user.dart
//
// Entidad de dominio para el usuario autenticado. Sin dependencias de
// Firebase: la capa de datos (AuthRepositoryImpl) es la única que sabe
// convertir un firebase_auth.User a este tipo.

class AppUser {
  final String uid;
  final String? email;
  final bool emailVerified;

  const AppUser({
    required this.uid,
    this.email,
    required this.emailVerified,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'AppUser(uid: $uid, email: $email)';
}
