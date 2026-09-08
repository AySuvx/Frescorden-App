// lib/domain/repositories/i_household_repository.dart
//
// Contrato (interfaz) que define QUÉ puede hacerse con hogares (Household),
// sin especificar CÓMO. El dominio depende de esta abstracción; la
// implementación real (Firestore) vive en lib/data/.
//
// Regla de dependencias de Clean Architecture:
//   domain ← data (data implementa domain, no al revés)

import '../entities/household.dart';

/// Excepción de dominio para casos de unión a un hogar que no vienen
/// directamente de Firebase, para que la presentación muestre el mensaje
/// sin conocer el tipo de excepción original (mismo patrón que AuthException).
class HouseholdException implements Exception {
  final String message;
  const HouseholdException(this.message);

  @override
  String toString() => message;
}

abstract interface class IHouseholdRepository {
  /// Emite el `activeHouseholdId` del usuario [uid] cada vez que cambia en
  /// su documento de perfil (`usuarios/{uid}`), o `null` si no tiene hogar
  /// activo.
  Stream<String?> watchActiveHouseholdId(String uid);

  /// Emite el [Household] con el [householdId] indicado cada vez que
  /// cambia (miembros, código de invitación, etc.), o `null` si fue
  /// eliminado / no existe.
  Stream<Household?> watchHousehold(String householdId);

  /// Crea un hogar nuevo con [name], vincula a [creatorUid] como
  /// administrador y primer miembro, y actualiza su `activeHouseholdId`.
  /// [creatorEmail] se guarda denormalizado en `memberEmails` para que la
  /// UI pueda mostrar quién es cada miembro sin leer perfiles ajenos.
  Future<Household> createHousehold({
    required String name,
    required String creatorUid,
    String? creatorEmail,
  });

  /// Busca un hogar por [code], verifica que no haya expirado, añade [uid]
  /// a `members` (y [email] a `memberEmails`) y actualiza su
  /// `activeHouseholdId`.
  ///
  /// Lanza [HouseholdException] si el código no existe o ya expiró.
  Future<Household> joinHouseholdByCode({
    required String code,
    required String uid,
    String? email,
  });

  /// Genera y guarda un código de invitación nuevo (con expiración de 24h)
  /// para el hogar [householdId]. Cualquier miembro puede renovarlo.
  /// Devuelve el código nuevo.
  Future<String> generateNewInviteCode(String householdId);

  /// Migración desde el modelo anterior (inventario por usuario individual)
  /// hacia el modelo de hogares compartidos: si [uid] todavía no tiene
  /// `activeHouseholdId`, le crea un hogar personal ("Mi hogar") y copia
  /// (sin borrar) los productos que ya tenía registrados hacia el nuevo
  /// hogar. No hace nada si [uid] ya tiene un hogar activo — seguro de
  /// llamar más de una vez (p. ej. desde varios dispositivos a la vez).
  Future<void> bootstrapPersonalHousehold(String uid, {String? email});

  /// Quita a [memberUid] de `members`/`memberEmails` del hogar
  /// [householdId]. La usan tanto "Salir del hogar" (el propio miembro se
  /// quita) como "Expulsar" (el admin quita a otro) — restringir que solo
  /// el admin pueda expulsar a otros es responsabilidad de la capa de
  /// presentación (HouseholdProvider), no de este método.
  Future<void> removeMember({
    required String householdId,
    required String memberUid,
  });

  /// Limpia el `activeHouseholdId` de [uid] (lo deja sin hogar activo).
  /// Usado al salir de un hogar, y como autocorrección del lado del
  /// miembro cuando detecta que fue expulsado (ver HouseholdProvider): el
  /// stream de watchActiveHouseholdId recoge el `null` y dispara el
  /// bootstrap de un hogar personal nuevo, igual que un usuario sin hogar.
  Future<void> clearActiveHousehold(String uid);
}
