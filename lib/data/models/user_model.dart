// Modelo del documento de perfil del usuario en Firestore (`usuarios/{uid}`
// — mismo nombre de colección que usan FirestoreProductDataSource y
// FirestoreProductHistoryDataSource; no se crea una colección `users`
// nueva para no fragmentar los datos). `activeHouseholdId` es el hogar
// familiar que el usuario tiene seleccionado — el inventario que ve es el
// de ese hogar.

class UserModel {
  final String uid;

  /// Hogar activo del usuario, o `null` si todavía no creó ni se unió a
  /// ninguno.
  final String? activeHouseholdId;

  /// El hogar personal ("Mi hogar") que se le creó la primera vez que usó
  /// la app — a diferencia de `activeHouseholdId` (cambia al unirse/salir
  /// de otros hogares), ESTE nunca se pisa. Permite que "Salir del Hogar"
  /// reactive el hogar personal de siempre en vez de crear uno nuevo vacío
  /// cada vez (ver FirestoreHouseholdDataSource.bootstrapPersonalHousehold —
  /// bug real encontrado en el piloto: salir de un hogar unido dejaba el
  /// inventario propio huérfano en un hogar al que ya no se podía volver).
  final String? personalHouseholdId;

  const UserModel({
    required this.uid,
    this.activeHouseholdId,
    this.personalHouseholdId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {required String uid}) {
    return UserModel(
      uid: uid,
      activeHouseholdId: json['activeHouseholdId'] as String?,
      personalHouseholdId: json['personalHouseholdId'] as String?,
    );
  }

  /// Listo para `.set(..., SetOptions(merge: true))`: solo toca el campo
  /// que este modelo conoce, sin pisar otros datos futuros del documento.
  Map<String, dynamic> toJson() {
    return {
      'activeHouseholdId': activeHouseholdId,
      if (personalHouseholdId != null)
        'personalHouseholdId': personalHouseholdId,
    };
  }
}
