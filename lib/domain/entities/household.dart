// lib/domain/entities/household.dart
//
// Módulo de Grupos Familiares (Household):
// Entidad de dominio que representa un hogar/grupo familiar compartido.
// El inventario (Product) pasa a vivir bajo el hogar activo del usuario
// (households/{id}/productos) en vez de por usuario individual — así todos
// los miembros ven y editan el mismo inventario en tiempo real.
//
// `inviteCode` + `codeExpiresAt`: código de 6 caracteres para que otro
// usuario se una al hogar (ver InviteCodeGenerator). Expira a las 24h de
// generado; después de eso deja de servir para unirse hasta que alguien
// del hogar genere uno nuevo (generateNewInviteCode).

class Household {
  final String id;
  final String name;

  /// uid del usuario que creó el hogar (administrador).
  final String createdBy;

  /// uids de todos los miembros del hogar, incluyendo al creador.
  final List<String> members;

  /// uid → email, para mostrar en la UI ("Mi Hogar") sin necesitar leer el
  /// documento de perfil de cada miembro (que las reglas de Firestore
  /// restringen a su propio dueño). Se completa al crear el hogar y al
  /// unirse (ver HouseholdProvider) — denormalizado a propósito.
  final Map<String, String> memberEmails;

  final String inviteCode;
  final DateTime codeExpiresAt;
  final DateTime createdAt;

  const Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    this.memberEmails = const {},
    required this.inviteCode,
    required this.codeExpiresAt,
    required this.createdAt,
  });

  /// `true` cuando [inviteCode] ya no sirve para que alguien se una.
  bool get isInviteCodeExpired => DateTime.now().isAfter(codeExpiresAt);

  bool isMember(String uid) => members.contains(uid);

  bool isAdmin(String uid) => createdBy == uid;

  Household copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
    Map<String, String>? memberEmails,
    String? inviteCode,
    DateTime? codeExpiresAt,
    DateTime? createdAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      memberEmails: memberEmails ?? this.memberEmails,
      inviteCode: inviteCode ?? this.inviteCode,
      codeExpiresAt: codeExpiresAt ?? this.codeExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Household &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Household(id: $id, name: $name, members: ${members.length})';
}
