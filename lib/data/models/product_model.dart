// lib/data/models/product_model.dart
//
// Extiende la entidad Product añadiendo la lógica de serialización/
// deserialización hacia y desde Firestore y Map<String,dynamic>.
// Las pantallas y el dominio nunca deben importar este archivo directamente;
// solo la capa de datos lo usa.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    super.barcode,
    required super.quantity,
    required super.unit,
    super.imagePath,
    super.expirationDate,
    super.createdAt,
    required super.entryDate,
    super.isBulk,
    super.category,
    super.minStock,
  });

  // ─── Desde Firestore ───────────────────────────────────────────────────────

  /// Crea un [ProductModel] a partir de un documento Firestore.
  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ProductModel._fromMap(data, docId: doc.id);
  }

  /// Crea un [ProductModel] a partir de un Map ya enriquecido con 'id'.
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel._fromMap(map, docId: map['id'] as String? ?? '');
  }

  factory ProductModel._fromMap(
    Map<String, dynamic> data, {
    required String docId,
  }) {
    // quantity puede llegar como String (legacy) o como int
    int parseQty(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    // imagePath con fallback a campo 'image' legacy (Bug #11)
    final imagePath = data['imagePath'] as String? ?? data['image'] as String?;

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    // minStock puede llegar como int, String o no venir (docs legacy).
    int? parseMinStock(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return ProductModel(
      id: docId,
      name: data['name'] as String? ?? '',
      barcode: data['barcode'] as String?,
      quantity: parseQty(data['quantity']),
      unit: data['unit'] as String? ?? 'unidad',
      imagePath: imagePath,
      expirationDate: parseDate(data['expirationDate']),
      createdAt: parseDate(data['createdAt']),
      // entryDate es obligatoria. Prioridad de resolución:
      // 1) 'entryDate' (campo actual), 2) 'storedAt' (nombre legacy previo
      // a esta formalización — se preserva el dato real del usuario en vez
      // de descartarlo), 3) DateTime.now() si el doc no trae ninguno de los
      // dos (docs antiguos, o creados sin fecha).
      entryDate: parseDate(data['entryDate']) ??
          parseDate(data['storedAt']) ??
          DateTime.now(),
      isBulk: data['isBulk'] as bool? ?? false,
      // docs creados antes de esta fase no traen 'category':
      // fromName() los resuelve como FoodCategory.otros.
      category: FoodCategory.fromName(data['category'] as String?),
      minStock: parseMinStock(data['minStock']),
    );
  }

  // ─── Hacia Firestore ───────────────────────────────────────────────────────

  /// Devuelve el Map listo para escribir en Firestore.
  /// Nota: 'id' se omite porque es el docId, no un campo del documento.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'quantity': quantity.toString(), // legacy: guardado como String
      'unit': unit,
      if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
      if (expirationDate != null)
        'expirationDate': expirationDate!.toIso8601String(),
      'entryDate': entryDate.toIso8601String(),
      'isBulk': isBulk,
      'category': category.name,
      if (minStock != null) 'minStock': minStock,
    };
  }

  // ─── Conversión desde entidad ──────────────────────────────────────────────

  /// Convierte cualquier [Product] (entidad) a [ProductModel].
  static ProductModel fromEntity(Product entity) {
    if (entity is ProductModel) return entity;
    return ProductModel(
      id: entity.id,
      name: entity.name,
      barcode: entity.barcode,
      quantity: entity.quantity,
      unit: entity.unit,
      imagePath: entity.imagePath,
      expirationDate: entity.expirationDate,
      createdAt: entity.createdAt,
      entryDate: entity.entryDate,
      isBulk: entity.isBulk,
      category: entity.category,
      minStock: entity.minStock,
    );
  }
}
