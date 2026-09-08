// lib/domain/entities/product.dart
//
// Trazabilidad de perecederos a granel (formalizado):
// El antiguo `storedAt` (DateTime nullable, opt-in) se reemplaza por
// `entryDate` (DateTime, obligatorio): fecha en que el producto entró al
// inventario. Todo producto la tiene — si no se registró explícitamente,
// ProductModel.fromMap la resuelve a DateTime.now() (ver ese archivo).
//
// `isBulk` (bool) marca productos de plaza/mercado comprados a granel
// (tomate, papa, frutas sin fecha de caducidad impresa) — se setea desde
// el flujo "Registro a Granel" del FAB (AddProductScreen.isBulkEntry).
// Solo estos productos muestran el badge "Almacenado hace N días" en la
// tarjeta de inventario: para un producto empacado recién agregado, ese
// dato no aporta nada (siempre diría "0 días").
//
// Computed getter `daysInStorage`: días transcurridos desde entryDate.
// Ya no es nullable — entryDate siempre existe.
//
// Categorización de Alimentos (#1):
// Se añade `category` (FoodCategory, no nula). Los productos ya existentes
// en Firestore que no tenían este campo se reconstruyen como
// `FoodCategory.otros` (ver ProductModel._fromMap / FoodCategory.fromName).
//
// Alertas de Stock mínimo (#2):
// Se añade `minStock` (int? opcional). Cuando el usuario lo define, el
// producto se considera en "stock bajo" cuando `quantity <= minStock`.
// Si no se define, el producto nunca dispara la alerta (comportamiento
// por defecto para no molestar a quien no usa esta función).

import 'food_category.dart';

class Product {
  final String id;
  final String name;
  final String? barcode;
  final int quantity;
  final String unit;
  final String? imagePath;
  final DateTime? expirationDate;
  final DateTime? createdAt;

  /// Fecha en que el producto entró al inventario (nevera/despensa).
  /// Obligatoria: si el usuario no la registra explícitamente, se resuelve
  /// a DateTime.now() en la capa de datos (ver ProductModel).
  final DateTime entryDate;

  /// `true` cuando el producto se registró vía "Registro a Granel"
  /// (perecederos de plaza/mercado, sin fecha de caducidad impresa).
  final bool isBulk;

  /// Categoría del alimento. No nula: los productos sin categoría
  /// asignada (creados antes de esta fase) se tratan como [FoodCategory.otros].
  final FoodCategory category;

  /// Cantidad mínima deseada. `null` significa que el usuario no
  /// activó la alerta de stock para este producto.
  final int? minStock;

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.unit,
    this.imagePath,
    this.expirationDate,
    this.createdAt,
    required this.entryDate,
    this.isBulk = false,
    this.category = FoodCategory.otros,
    this.minStock,
  });

  /// Días transcurridos desde que el producto entró al inventario.
  int get daysInStorage => DateTime.now().difference(entryDate).inDays;

  /// Días que faltan para el vencimiento (negativo si ya venció).
  /// `null` cuando el producto no tiene fecha de vencimiento registrada.
  int? get daysToExpiration =>
      expirationDate?.difference(DateTime.now()).inDays;

  /// Indica si el tiempo almacenado merece una alerta visual.
  /// Solo relevante para productos a granel (`isBulk`); un producto
  /// empacado normal no dispara esta alerta aunque lleve muchos días.
  ///
  /// TODO(Roadmap Fase 4): hoy `isStorageCritical` solo alimenta el badge
  /// visual en la tarjeta de inventario (productos_screen.dart). No dispara
  /// ninguna notificación push cuando un producto a granel lleva
  /// `storageCriticalDays` o más almacenado — a diferencia de
  /// `expirationDate`, que sí programa una alarma real (ver
  /// AddProductScreen._scheduleNotification). Pendiente: decidir el
  /// disparador (¿job periódico? ¿al abrir la app?) y programarlo.
  bool get isStorageCritical => isBulk && daysInStorage >= storageCriticalDays;

  /// Umbral de días para considerar el almacenamiento "crítico".
  /// Valor por defecto: 5 días. Se puede personalizar por producto en futuras fases.
  int get storageCriticalDays => 5;

  /// Alertas de Stock mínimo (#2):
  /// `true` cuando el usuario definió `minStock` y la cantidad actual ya
  /// llegó a ese umbral o está por debajo. Si `minStock` es `null`, el
  /// producto nunca se marca en stock bajo.
  bool get isLowStock => minStock != null && quantity <= minStock!;

  /// Crea una copia con los campos indicados modificados.
  ///
  /// Nota sobre `minStock`: al ser un `int?` que también debe poder
  /// *limpiarse* explícitamente (volver a `null`), se usa el parámetro
  /// [clearMinStock] en vez del truco `?? this.minStock` (que impediría
  /// borrar el umbral una vez fue asignado).
  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    int? quantity,
    String? unit,
    String? imagePath,
    DateTime? expirationDate,
    DateTime? createdAt,
    DateTime? entryDate,
    bool? isBulk,
    FoodCategory? category,
    int? minStock,
    bool clearMinStock = false,
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
      entryDate: entryDate ?? this.entryDate,
      isBulk: isBulk ?? this.isBulk,
      category: category ?? this.category,
      minStock: clearMinStock ? null : (minStock ?? this.minStock),
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
      'image': imagePath, // alias retrocompatibilidad (Bug #11)
      'expirationDate': expirationDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'entryDate': entryDate.toIso8601String(),
      'isBulk': isBulk,
      'category': category.name,
      'minStock': minStock,
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
      'exp: $expirationDate, entryDate: $entryDate, isBulk: $isBulk)';
}
