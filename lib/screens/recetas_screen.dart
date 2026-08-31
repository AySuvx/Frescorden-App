// lib/screens/recetas_screen.dart
//
// FASE 2 (Fresc-O-rden) — Módulo de Recetas:
// Se elimina el mock (List<Map> hardcodeada + verificarIngredientes()) y
// se conecta a RecipeProvider + ProductProvider. Ya no recibe el inventario
// por parámetro (productosInventario): lo lee directamente del provider,
// igual que ya hacía ShoppingListScreen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/recipe.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/providers/recipe_provider.dart';
import 'detalle_receta_screen.dart';

class RecetasScreen extends StatefulWidget {
  const RecetasScreen({super.key});

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen> {
  bool mostrarSoloDisponibles = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final inventory = context.watch<ProductProvider>().products;

    final recetasFiltradas = mostrarSoloDisponibles
        ? recipeProvider.availableRecipes(inventory)
        : recipeProvider.recipes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetas Sugeridas'),
        actions: [
          IconButton(
            icon: Icon(
              mostrarSoloDisponibles ? Icons.filter_alt : Icons.filter_alt_off,
            ),
            tooltip: mostrarSoloDisponibles
                ? "Mostrar recetas con productos que no tienes"
                : "Mostrar todas las recetas",
            onPressed: () {
              setState(() {
                mostrarSoloDisponibles = !mostrarSoloDisponibles;
              });
            },
          )
        ],
      ),
      body: recipeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : recetasFiltradas.isEmpty
              ? const Center(
                  child: Text('No hay recetas disponibles con tus productos 😥'))
              : ListView.builder(
                  itemCount: recetasFiltradas.length,
                  itemBuilder: (context, index) {
                    final Recipe receta = recetasFiltradas[index];
                    final faltantes =
                        recipeProvider.missingIngredientsFor(receta, inventory);
                    final disponible = faltantes.isEmpty;

                    return Card(
                      color: disponible ? Colors.white : Colors.grey[200],
                      elevation: 2,
                      margin:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: ListTile(
                        leading: Image.asset(
                          receta.imagePath,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(receta.name),
                        subtitle: Text(
                          disponible
                              ? 'Puedes preparar esta receta'
                              : 'Faltan: ${faltantes.map((f) => f.name).join(', ')}',
                        ),
                        trailing: Icon(
                          disponible ? Icons.check_circle : Icons.warning,
                          color: disponible ? Colors.green : Colors.orange,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalleRecetaScreen(
                                receta: receta,
                                faltantes: faltantes,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
