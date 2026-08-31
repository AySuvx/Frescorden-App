// lib/screens/detalle_receta_screen.dart
//
// Módulo de Recetas:
// Recibe la entidad Recipe (y sus RecipeIngredient faltantes) en vez de
// Map<String,dynamic>. Los pasos de preparación, antes en un switch
// hardcodeado aquí mismo, ahora vienen de receta.steps (cargados desde
// assets/data/recetas.json vía RecipeProvider).

import 'package:flutter/material.dart';
import '../domain/entities/recipe.dart';
import '../domain/entities/recipe_ingredient.dart';

class DetalleRecetaScreen extends StatelessWidget {
  final Recipe receta;
  final List<RecipeIngredient> faltantes;

  const DetalleRecetaScreen({
    super.key,
    required this.receta,
    required this.faltantes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(receta.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la receta
            Center(
              child: Image.asset(
                receta.imagePath,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // Número de personas
            Text(
              'Para ${receta.servings} personas',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Ingredientes
            const Text(
              'Ingredientes:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...receta.ingredients.map<Widget>((ingrediente) {
              final tieneIngrediente =
                  !faltantes.any((f) => f.name == ingrediente.name);
              return Row(
                children: [
                  Icon(
                    tieneIngrediente ? Icons.check_circle : Icons.cancel,
                    color: tieneIngrediente ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${ingrediente.name} - ${ingrediente.quantity} ${ingrediente.unit}',
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Pasos de preparación
            const Text(
              'Preparación:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...receta.steps.map((paso) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('- $paso'),
              );
            }),
          ],
        ),
      ),
    );
  }
}
