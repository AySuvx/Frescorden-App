// lib/domain/entities/product.dart
//
// Entidad central de dominio. Clase Dart pura: sin dependencias de Flutter,
// Firebase ni ningún framework externo. Es el único "Product" verdadero
// del sistema; todos los demás (ProductModel, Maps en pantallas) derivan de él.
//
// Decisiones de diseño:
//  - `quantity` es int internamente; `toMap()` lo convierte a String para
//    retrocompatibilidad con las pantallas y documentos Firestore existentes.
//  - `id` es String vacía ('') cuando el producto aún no ha sido persistido.
//  - Todos los campos opcionales (barcode, imagePath, etc.) son nullable.

class Product {
  final String id;
  final String name;
  final String? barcode;
  final int quantity;
  final String unit;
  final String? imagePath;
  final DateTime? expirationDate;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.unit,
    this.imagePath,
    this.expirationDate,
    this.createdAt,
  });

  /// Crea una copia con los campos indicados modificados.
  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    int? quantity,
    String? unit,
    String? imagePath,
    DateTime? expirationDate,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      imagePath: imagePath ?? this.imagePath,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte la entidad a Map<String, dynamic> compatible con el formato
  /// que las pantallas existentes ya esperan (quantity como String).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'quantity': quantity.toString(),
      'unit': unit,
      'imagePath': imagePath,
      'image': imagePath,            // alias retrocompatibilidad (Bug #11)
      'expirationDate': expirationDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Product(id: $id, name: $name, qty: $quantity $unit, exp: $expirationDate)';
}
