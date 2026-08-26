// lib/domain/entities/product.dart
//
// FASE 3 — Trazabilidad de perecederos a granel:
// Se añade el campo `storedAt` (DateTime nullable).
// Representa la fecha en que el producto fue almacenado en la nevera/despensa.
// Se usa principalmente para productos de plaza/mercado (tomate, papa, frutas)
// donde no existe una fecha de caducidad impresa, pero el usuario quiere saber
// cuántos días lleva en casa.
//
// Computed getter `daysStored`: retorna los días transcurridos desde storedAt,
// o null si el campo no fue registrado.

class Product {
  final String id;
  final String name;
  final String? barcode;
  final int quantity;
  final String unit;
  final String? imagePath;
  final DateTime? expirationDate;
  final DateTime? createdAt;

  /// FASE 3 — Fecha de almacenamiento en nevera/despensa.
  /// Opcional: solo se registra cuando el usuario lo indica explícitamente.
  final DateTime? storedAt;

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.unit,
    this.imagePath,
    this.expirationDate,
    this.createdAt,
    this.storedAt,
  });

  /// FASE 3 — Días transcurridos desde que el producto fue almacenado.
  /// Retorna `null` si `storedAt` no fue registrado.
  int? get daysStored {
    if (storedAt == null) return null;
    return DateTime.now().difference(storedAt!).inDays;
  }

  /// FASE 3 — Indica si el tiempo almacenado merece una alerta visual.
  /// Cada categoría tiene un umbral diferente (en días).
  bool get isStorageCritical {
    final days = daysStored;
    if (days == null) return false;
    return days >= storageCriticalDays;
  }

  /// Umbral de días para considerar el almacenamiento "crítico".
  /// Valor por defecto: 5 días. Se puede personalizar por producto en futuras fases.
  int get storageCriticalDays => 5;

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
    DateTime? storedAt,
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
      storedAt: storedAt ?? this.storedAt,
    );
  }

  /// Convierte la entidad a `Map<String, dynamic>` compatible con el formato
  /// que las pantallas existentes ya esperan (quantity como String).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'quantity': quantity.toString(),
      'unit': unit,
      'imagePath': imagePath,
      'image': imagePath,               // alias retrocompatibilidad (Bug #11)
      'expirationDate': expirationDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'storedAt': storedAt?.toIso8601String(),     // FASE 3
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
      'Product(id: $id, name: $name, qty: $quantity $unit, '
      'exp: $expirationDate, storedAt: $storedAt)';
}
