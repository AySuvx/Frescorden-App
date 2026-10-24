import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Historia de Usuario: Como cliente, necesito que la aplicación sugiera recetas', () {
    test('Escenario: Sugerir recetas con productos suficientes en el inventario', () {
      List<Map<String, dynamic>> inventario = [
        {'name': 'Arroz', 'quantity': 2},
        {'name': 'Pollo', 'quantity': 1},
        {'name': 'Tomate', 'quantity': 3}
      ];

      List<Map<String, dynamic>> recetas = [
        {'name': 'Arroz con Pollo', 'ingredients': ['Arroz', 'Pollo']},
        {'name': 'Ensalada', 'ingredients': ['Tomate']},
      ];

      List<String> recetasSugeridas = sugerirRecetas(inventario, recetas);

      expect(recetasSugeridas.contains('Arroz con Pollo'), true);
      expect(recetasSugeridas.contains('Ensalada'), true);
    });

    test('Escenario: No sugerir recetas si no hay productos suficientes', () {
      List<Map<String, dynamic>> inventario = [
        {'name': 'Arroz', 'quantity': 0},
        {'name': 'Pollo', 'quantity': 1}
      ];

      List<Map<String, dynamic>> recetas = [
        {'name': 'Arroz con Pollo', 'ingredients': ['Arroz', 'Pollo']},
      ];

      List<String> recetasSugeridas = sugerirRecetas(inventario, recetas);

      expect(recetasSugeridas.isEmpty, true);
    });
  });
}

// Función para sugerir recetas
List<String> sugerirRecetas(List<Map<String, dynamic>> inventario, List<Map<String, dynamic>> recetas) {
  List<String> recetasSugeridas = [];

  for (var receta in recetas) {
    bool puedePreparar = true;

    for (var ingrediente in receta['ingredients']) {
      if (!inventario.any((producto) => producto['name'] == ingrediente && producto['quantity'] > 0)) {
        puedePreparar = false;
        break;
      }
    }

    if (puedePreparar) {
      recetasSugeridas.add(receta['name']);
    }
  }

  return recetasSugeridas;
}
