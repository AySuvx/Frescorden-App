// lib/data/models/user_model.dart
//
// Modelo del documento de perfil del usuario en Firestore
// (`usuarios/{uid}` — mismo nombre de colección que ya usan
// FirestoreProductDataSource y FirestoreProductHistoryDataSource; no se
// crea una colección `users` nueva para no fragmentar los datos).
//
// Hoy ese documento solo existe implícitamente como padre de las
// subcolecciones `productos`/`historial` (nunca se le habían escrito campos
// propios). `activeHouseholdId` es el primer campo real que persiste aquí:
// el hogar familiar (Household) que el usuario tiene seleccionado en este
// momento — el inventario que ve es el de ese hogar.

class UserModel {
  final String uid;

  /// Hogar activo del usuario, o `null` si todavía no creó ni se unió a
  /// ninguno.
  final String? activeHouseholdId;

  const UserModel({required this.uid, this.activeHouseholdId});

  factory UserModel.fromJson(Map<String, dynamic> json, {required String uid}) {
    return UserModel(
      uid: uid,
      activeHouseholdId: json['activeHouseholdId'] as String?,
    );
  }

  /// Listo para `.set(..., SetOptions(merge: true))`: solo toca el campo
  /// que este modelo conoce, sin pisar otros datos futuros del documento.
  Map<String, dynamic> toJson() {
    return {'activeHouseholdId': activeHouseholdId};
  }
}
