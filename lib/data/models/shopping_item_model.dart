// lib/data/models/shopping_item_model.dart
//
// Modelo de datos: traduce entre el JSON de assets/data/canastas.json y la
// entidad de dominio [ShoppingItem].

import '../../domain/entities/shopping_item.dart';

class ShoppingItemModel {
  static ShoppingItem fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      name: json['nombre'] as String,
      quantity: (json['cantidad'] as num?) ?? 0,
      unit: json['unidad'] as String? ?? '',
      category: json['categoria'] as String? ?? 'otros',
      estimatedPrice: (json['precioEstimado'] as num?)?.toInt(),
    );
  }
}
