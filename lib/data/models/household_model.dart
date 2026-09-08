// lib/data/models/household_model.dart
//
// Extiende la entidad Household añadiendo la lógica de serialización/
// deserialización hacia y desde Firestore (fromJson/toJson). Las pantallas
// y el dominio nunca deben importar este archivo directamente; solo la
// capa de datos lo usa (mismo patrón que ProductModel).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/household.dart';

class HouseholdModel extends Household {
  const HouseholdModel({
    required super.id,
    required super.name,
    required super.createdBy,
    required super.members,
    super.memberEmails,
    required super.inviteCode,
    required super.codeExpiresAt,
    required super.createdAt,
  });

  /// Crea un [HouseholdModel] a partir de un documento Firestore.
  factory HouseholdModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return HouseholdModel.fromJson(data, id: doc.id);
  }

  /// Crea un [HouseholdModel] a partir del JSON de un documento (sin `id`,
  /// ya que en Firestore es el docId, no un campo).
  factory HouseholdModel.fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return HouseholdModel(
      id: id,
      name: json['name'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      members: List<String>.from(json['members'] as List? ?? const []),
      memberEmails: Map<String, String>.from(
        json['memberEmails'] as Map? ?? const {},
      ),
      inviteCode: json['inviteCode'] as String? ?? '',
      codeExpiresAt: parseDate(json['codeExpiresAt']),
      createdAt: parseDate(json['createdAt']),
    );
  }

  /// Devuelve el JSON listo para escribir en Firestore.
  /// Nota: `id` se omite porque es el docId, no un campo del documento.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'memberEmails': memberEmails,
      'inviteCode': inviteCode,
      'codeExpiresAt': Timestamp.fromDate(codeExpiresAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convierte cualquier [Household] (entidad) a [HouseholdModel].
  static HouseholdModel fromEntity(Household entity) {
    if (entity is HouseholdModel) return entity;
    return HouseholdModel(
      id: entity.id,
      name: entity.name,
      createdBy: entity.createdBy,
      members: entity.members,
      memberEmails: entity.memberEmails,
      inviteCode: entity.inviteCode,
      codeExpiresAt: entity.codeExpiresAt,
      createdAt: entity.createdAt,
    );
  }
}
