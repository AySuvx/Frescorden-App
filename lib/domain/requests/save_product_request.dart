// DTO de entrada para registrar o editar un producto — reemplaza el
// Map<String, dynamic> sin tipar que usaba ProductProvider.saveProduct
// (ver P-03/DT-03 del diagnóstico). Tipado fuerte: el formulario ya no
// puede enviar una cantidad como texto inválido o una fecha mal formada
// sin que el compilador lo marque.

import '../entities/food_category.dart';

class SaveProductRequest {
  /// `null` para un producto nuevo; presente para editar uno existente.
  final String? id;
  final String name;
  final int quantity;
  final String unit;
  final String? imagePath;
  final DateTime? expirationDate;
  final DateTime entryDate;
  final bool isBulk;
  final FoodCategory category;
  final int? minStock;

  const SaveProductRequest({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.imagePath,
    this.expirationDate,
    required this.entryDate,
    this.isBulk = false,
    this.category = FoodCategory.otros,
    this.minStock,
  });

  bool get isEdit => id != null;
}
