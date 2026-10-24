// Paso intermedio del flujo "Por Categoría": en vez de ir directo al
// formulario en blanco, ofrece el catálogo curado de PresetFoodLocalDataSource
// para esa categoría. Elegir uno evita que el usuario tenga que escribir
// nombre/unidad a mano para algo ya bien clasificado (arroz, agua
// embotellada, enlatados, etc.) — ver PresetFood.
//
// Devuelve el PresetFood elegido vía Navigator.pop, o null si el usuario
// usa "No lo encuentro" (producto fuera del catálogo: el formulario en
// blanco de siempre) o el botón atrás.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme/app_spacing.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/preset_food.dart';
import '../../domain/repositories/i_preset_food_repository.dart';

class PresetFoodPickerScreen extends StatefulWidget {
  const PresetFoodPickerScreen({super.key, required this.category});

  final FoodCategory category;

  /// Valor de retorno de "No lo encuentro, continuar manualmente" —
  /// distinto de `null` (que significa "canceló con el botón atrás": no
  /// avanzar al formulario en absoluto). El llamador compara con `==` para
  /// distinguir los tres resultados posibles: PresetFood elegido, este
  /// centinela (formulario en blanco), o null (cancelar).
  static const Object manualEntry = Object();

  @override
  State<PresetFoodPickerScreen> createState() => _PresetFoodPickerScreenState();
}

class _PresetFoodPickerScreenState extends State<PresetFoodPickerScreen> {
  late final Future<List<PresetFood>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = context.read<IPresetFoodRepository>().getByCategory(
      widget.category,
    );
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.label)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar alimento...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PresetFood>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? const <PresetFood>[];
                final filtered =
                    _query.isEmpty
                        ? all
                        : all
                            .where((f) => f.name.toLowerCase().contains(_query))
                            .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        all.isEmpty
                            ? 'Todavía no hay alimentos preestablecidos en '
                                'esta categoría.'
                            : 'No encontramos "$_query" en esta categoría.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final food = filtered[index];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text('Unidad sugerida: ${food.unit}'),
                      onTap: () => Navigator.pop(context, food),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: OutlinedButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      PresetFoodPickerScreen.manualEntry,
                    ),
                child: const Text('No lo encuentro, continuar manualmente'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
