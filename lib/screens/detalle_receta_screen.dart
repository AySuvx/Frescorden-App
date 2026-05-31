import 'package:flutter/material.dart';

class DetalleRecetaScreen extends StatelessWidget {
  final Map<String, dynamic> receta;
  final List<Map<String, dynamic>> faltantes;

  const DetalleRecetaScreen({
    super.key,
    required this.receta,
    required this.faltantes,
  });

  @override
  Widget build(BuildContext context) {
    // Asignar un valor predeterminado si 'personas' es null
    final int personas = receta['personas'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(receta['nombre']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la receta
            Center(
              child: Image.asset(
                receta['imagen'],
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // Número de personas
            Text(
              'Para $personas personas',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Ingredientes
            Text(
              'Ingredientes:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...receta['ingredientes'].map<Widget>((ingrediente) {
              final tieneIngrediente = !faltantes.any((f) => f['nombre'] == ingrediente['nombre']);
              return Row(
                children: [
                  Icon(
                    tieneIngrediente ? Icons.check_circle : Icons.cancel,
                    color: tieneIngrediente ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${ingrediente['nombre']} - ${ingrediente['cantidad']} ${ingrediente['unidad']}',
                  ),
                ],
              );
            }).toList(),
            const SizedBox(height: 16),

            // Pasos de preparación
            Text(
              'Preparación:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._obtenerPasosPreparacion(receta['nombre']).map((paso) {
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

  // Pasos detallados de preparación según el nombre de la receta
  List<String> _obtenerPasosPreparacion(String nombreReceta) {
    switch (nombreReceta) {
      case 'Arepa con queso':
        return [
          '1. Calienta una sartén a fuego medio durante 2 minutos.',
          '2. Coloca las arepas en la sartén y caliéntalas durante 3 minutos por cada lado hasta que estén doradas.',
          '3. Mientras tanto, ralla el queso y tenlo listo.',
          '4. Retira las arepas de la sartén, unta mantequilla al gusto y coloca el queso rallado encima.',
          '5. Sirve inmediatamente mientras el queso está derretido. Tiempo total: 10 minutos.',
        ];
      case 'Huevos pericos':
        return [
          '1. Lava y pica finamente el tomate y la cebolla.',
          '2. Calienta una sartén con 10 ml de aceite a fuego medio durante 1 minuto.',
          '3. Sofríe el tomate y la cebolla durante 5 minutos, revolviendo ocasionalmente.',
          '4. En un recipiente aparte, bate los huevos con una pizca de sal.',
          '5. Vierte los huevos batidos en la sartén y cocina durante 3 minutos, revolviendo constantemente hasta que estén cocidos.',
          '6. Sirve caliente acompañado de pan o arepas. Tiempo total: 15 minutos.',
        ];
      case 'Caldo de papa':
        return [
          '1. Pela las papas y córtalas en trozos medianos.',
          '2. Pica finamente la cebolla y los dientes de ajo.',
          '3. En una olla grande, hierve 1 litro de agua con una pizca de sal.',
          '4. Agrega las papas, la cebolla y el ajo al agua hirviendo.',
          '5. Cocina a fuego medio durante 20 minutos o hasta que las papas estén blandas.',
          '6. Sirve caliente y, si lo deseas, acompaña con cilantro fresco. Tiempo total: 30 minutos.',
        ];
      case 'Arroz con pollo':
        return [
          '1. Corta el pollo en trozos pequeños y sazónalo con sal al gusto.',
          '2. Calienta una sartén grande con un poco de aceite y sofríe el pollo durante 5 minutos hasta que esté dorado.',
          '3. Pica la zanahoria, la cebolla y el pimentón en trozos pequeños.',
          '4. Agrega las verduras al pollo y cocina durante 5 minutos más, revolviendo ocasionalmente.',
          '5. Añade el arroz, 4 tazas de agua y una pizca de sal. Mezcla bien.',
          '6. Cocina a fuego medio durante 20 minutos o hasta que el arroz esté completamente cocido.',
          '7. Sirve caliente y disfruta. Tiempo total: 35 minutos.',
        ];
      case 'Changua':
        return [
          '1. En una olla grande, mezcla 500 ml de agua y 500 ml de leche. Lleva a ebullición a fuego medio.',
          '2. Pica finamente la cebolla y agrégala a la olla junto con una pizca de sal.',
          '3. Rompe los huevos directamente en la mezcla y cocina durante 3 minutos sin revolver.',
          '4. Sirve la changua caliente en un tazón y acompaña con rebanadas de pan tostado.',
          '5. Opcional: añade cilantro fresco picado para decorar. Tiempo total: 15 minutos.',
        ];
      default:
        return ['Pasos no disponibles para esta receta.'];
    }
  }
}