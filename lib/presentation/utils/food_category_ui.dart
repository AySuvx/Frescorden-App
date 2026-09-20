// Mapeo de FoodCategory -> asset de ícono (mascota Frescorden). Vive en
// `presentation` (y no en `domain`) porque la ruta del asset es un
// detalle de Flutter/UI, no una regla de negocio. Las pantallas importan
// esta extensión en vez de repetir el switch-case cada vez que necesitan
// mostrar un ícono de categoría.

import 'package:flutter/material.dart';
import '../../domain/entities/food_category.dart';

extension FoodCategoryUi on FoodCategory {
  String get iconAsset {
    switch (this) {
      case FoodCategory.lacteos:
        return 'assets/iconos/fresco_cat_lacteos.png';
      case FoodCategory.carnesYEmbutidos:
        return 'assets/iconos/fresco_cat_carnes.png';
      case FoodCategory.frutasYVerduras:
        return 'assets/iconos/fresco_cat_frutasyverduras.png';
      case FoodCategory.granosYCereales:
        return 'assets/iconos/fresco_cat_granos.png';
      case FoodCategory.panaderia:
        return 'assets/iconos/fresco_cat_panaderia.png';
      case FoodCategory.bebidas:
        return 'assets/iconos/fresco_cat_bebidas.png';
      case FoodCategory.congelados:
        return 'assets/iconos/fresco_cat_congelados.png';
      case FoodCategory.condimentosYSalsas:
        return 'assets/iconos/fresco_cat_condimentos.png';
      case FoodCategory.enlatadosYConservas:
        return 'assets/iconos/fresco_cat_enlatados.png';
      case FoodCategory.otros:
        return 'assets/iconos/fresco_cat_otros.png';
      case FoodCategory.frutas:
        return 'assets/iconos/fresco_cat_frutas.png';
      case FoodCategory.verdurasYHortalizas:
        return 'assets/iconos/fresco_cat_verduras.png';
    }
  }

  /// Color estable por categoría, usado en los gráficos de
  /// analíticas (WasteVsConsumedBarChart, WasteCategoryPieChart) y su
  /// leyenda. Mismo criterio que `icon`: es un detalle de presentación,
  /// no una regla de negocio, por eso vive aquí y no en el dominio.
  Color get chartColor {
    switch (this) {
      case FoodCategory.lacteos:
        return const Color(0xFF64B5F6); // azul
      case FoodCategory.carnesYEmbutidos:
        return const Color(0xFFE57373); // rojo
      case FoodCategory.frutasYVerduras:
        return const Color(0xFF81C784); // verde
      case FoodCategory.granosYCereales:
        return const Color(0xFFD4A76A); // marrón claro
      case FoodCategory.panaderia:
        return const Color(0xFFFFB74D); // naranja
      case FoodCategory.bebidas:
        return const Color(0xFF4DD0E1); // cian
      case FoodCategory.congelados:
        return const Color(0xFF9575CD); // morado
      case FoodCategory.condimentosYSalsas:
        return const Color(0xFFFFD54F); // amarillo
      case FoodCategory.enlatadosYConservas:
        return const Color(0xFF90A4AE); // gris azulado
      case FoodCategory.otros:
        return const Color(0xFFA1887F); // marrón neutro
      case FoodCategory.frutas:
        return const Color(0xFFFF8A65); // naranja rojizo
      case FoodCategory.verdurasYHortalizas:
        return const Color(0xFF66BB6A); // verde
    }
  }
}
