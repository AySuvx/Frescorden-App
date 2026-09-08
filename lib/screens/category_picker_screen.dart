// lib/screens/category_picker_screen.dart
//
// Paso previo del flujo "Por Categoría" del FAB: antes de abrir el
// formulario de producto, el usuario elige la categoría en un solo toque.
// Devuelve la [FoodCategory] elegida vía Navigator.pop, o null si canceló
// (botón atrás).

import 'package:flutter/material.dart';

import '../domain/entities/food_category.dart';
import '../presentation/utils/food_category_ui.dart';

class CategoryPickerScreen extends StatelessWidget {
  const CategoryPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige una categoría'),
        backgroundColor: Colors.green,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: FoodCategory.selectable.length,
        itemBuilder: (context, index) {
          final category = FoodCategory.selectable[index];
          return _CategoryTile(
            category: category,
            onTap: () => Navigator.pop(context, category),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final FoodCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = category.chartColor;
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
