import 'package:flutter/material.dart';
import 'detalle_receta_screen.dart';

class RecetasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> productosInventario;

  const RecetasScreen({super.key, required this.productosInventario});

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen> {
  bool mostrarSoloDisponibles = false;

  // Lista de recetas colombianas con cantidades requeridas
final List<Map<String, dynamic>> recetas = [
  {
    'nombre': 'Arepa con queso',
    'personas': 2, // Número de personas
    'ingredientes': [
      {'nombre': 'arepa', 'cantidad': 2, 'unidad': 'unidades'},
      {'nombre': 'queso', 'cantidad': 100, 'unidad': 'gramos'},
      {'nombre': 'mantequilla', 'cantidad': 20, 'unidad': 'gramos'},
    ],
    'imagen': 'assets/arepa.png',
  },
  {
    'nombre': 'Huevos pericos',
    'personas': 2, // Número de personas
    'ingredientes': [
      {'nombre': 'huevos', 'cantidad': 3, 'unidad': 'unidades'},
      {'nombre': 'tomate', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'cebolla', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'aceite', 'cantidad': 10, 'unidad': 'ml'},
      {'nombre': 'sal', 'cantidad': 1, 'unidad': 'pizca'},
    ],
    'imagen': 'assets/huevos_pericos.png',
  },
  {
    'nombre': 'Caldo de papa',
    'personas': 4, // Número de personas
    'ingredientes': [
      {'nombre': 'papas', 'cantidad': 3, 'unidad': 'unidades'},
      {'nombre': 'cebolla', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'ajo', 'cantidad': 2, 'unidad': 'dientes'},
      {'nombre': 'agua', 'cantidad': 1, 'unidad': 'litro'},
      {'nombre': 'sal', 'cantidad': 1, 'unidad': 'pizca'},
    ],
    'imagen': 'assets/caldo_papa.png',
  },
  {
    'nombre': 'Arroz con pollo',
    'personas': 4, // Número de personas
    'ingredientes': [
      {'nombre': 'arroz', 'cantidad': 2, 'unidad': 'tazas'},
      {'nombre': 'pollo', 'cantidad': 500, 'unidad': 'gramos'},
      {'nombre': 'zanahoria', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'cebolla', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'pimentón', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'agua', 'cantidad': 4, 'unidad': 'tazas'},
      {'nombre': 'sal', 'cantidad': 1, 'unidad': 'pizca'},
    ],
    'imagen': 'assets/arroz_pollo.png',
  },
  {
    'nombre': 'Changua',
    'personas': 2, // Número de personas
    'ingredientes': [
      {'nombre': 'leche', 'cantidad': 500, 'unidad': 'ml'},
      {'nombre': 'agua', 'cantidad': 500, 'unidad': 'ml'},
      {'nombre': 'huevo', 'cantidad': 2, 'unidad': 'unidades'},
      {'nombre': 'cebolla', 'cantidad': 1, 'unidad': 'unidad'},
      {'nombre': 'pan', 'cantidad': 2, 'unidad': 'rebanadas'},
      {'nombre': 'sal', 'cantidad': 1, 'unidad': 'pizca'},
    ],
    'imagen': 'assets/changua.png',
  },
];

  // Comprueba si en el inventario se tienen todos los ingredientes necesarios para una receta.
  Map<String, dynamic> verificarIngredientes(List<Map<String, dynamic>> necesarios) {
    final nombresInventario = widget.productosInventario
        .map((producto) => producto['name'].toString().toLowerCase())
        .toList();

    final faltantes = necesarios
        .where((ingrediente) => !nombresInventario.contains(ingrediente['nombre'].toLowerCase()))
        .toList();

    return {
      'tieneTodos': faltantes.isEmpty,
      'faltantes': faltantes,
    };
  }

  @override
  Widget build(BuildContext context) {
    final recetasFiltradas = mostrarSoloDisponibles
        ? recetas.where((receta) => verificarIngredientes(receta['ingredientes'])['tieneTodos']).toList()
        : recetas;

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
      body: recetasFiltradas.isEmpty
          ? const Center(child: Text('No hay recetas disponibles con tus productos 😥'))
          : ListView.builder(
              itemCount: recetasFiltradas.length,
              itemBuilder: (context, index) {
                final receta = recetasFiltradas[index];
                final resultado = verificarIngredientes(receta['ingredientes']);
                final disponible = resultado['tieneTodos'];
                final faltantes = resultado['faltantes'];

                return Card(
                  color: disponible ? Colors.white : Colors.grey[200],
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: ListTile(
                    leading: Image.asset(
                      receta['imagen'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(receta['nombre']),
                    subtitle: Text(
                      disponible
                          ? 'Puedes preparar esta receta'
                          : 'Faltan: ${faltantes.map((f) => f['nombre']).join(', ')}',
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
