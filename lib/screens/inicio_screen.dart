// lib/screens/inicio_screen.dart
//
// FASE 2 — Clean Architecture:
// Toda la lógica de Firestore (cargar, agregar, acumular, eliminar) ha sido
// removida de esta pantalla y centralizada en ProductProvider.
//
// Cambios respecto a Fase 1:
//  - Eliminados: _cargarProductosDesdeFirestore(), agregarOActualizarProducto(),
//    editarProducto(), eliminarProductoConConfirmacion() (eran accesos directos
//    a Firestore; ahora viven en ProductProvider).
//  - La lista de productos se lee de context.watch<ProductProvider>().productosMap.
//  - initState solo llama provider.loadProducts() — sin Firestore directo.
//  - Los callbacks de sub-pantallas recargan vía provider.loadProducts().
//
// La UI y el comportamiento visible son IDÉNTICOS al de Fase 1.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/product_provider.dart';
import 'recetas_screen.dart';
import 'productos_screen.dart';
import 'add_product_screen.dart';
import '../Widgets/button_plus.dart';
import 'login_screen.dart';
import 'shopping_list_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'contact_screen.dart';
import 'about_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  @override
  void initState() {
    super.initState();
    // Carga inicial delegada al provider; no hay Firestore directo aquí.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  Future<void> cerrarSesion() async {
    await context.read<AuthProvider>().signOut();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Navega a AddProductScreen para AGREGAR un producto.
  ///
  /// BUG CRÍTICO CORREGIDO (hallado probando la app en dispositivo físico):
  /// AddProductScreen._guardarProducto() ya llama a
  /// `context.read<ProductProvider>().saveProduct()` directamente — este
  /// callback `onSave` volvía a llamarlo, guardando CADA producto DOS VECES
  /// por cada tap en "Guardar" (la lógica de acumular-por-nombre duplicaba
  /// la cantidad cada vez). Preexistente desde Fase 2; quedó oculto detrás
  /// del bug de casteo ProductModel corregido antes en esta misma sesión,
  /// que siempre lanzaba excepción antes de que la duplicación fuera
  /// visible. `onSave` se mantiene como hook opcional (no persiste nada)
  /// por si una futura pantalla necesita reaccionar al guardado sin
  /// duplicar la escritura.
  ///
  /// Fase 2 — Limpieza de escáner: ya no existe el flujo de escaneo, así que
  /// toda alta nueva es manual (`isManualAdd: true`). [isBulkEntry] distingue
  /// el "Registro a Granel" del alta estándar por categoría.
  void _navegarAgregarProducto({bool isBulkEntry = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddProductScreen(
              onSave: (_) {},
              isManualAdd: true,
              isBulkEntry: isBulkEntry,
            ),
      ),
    );
  }

  /// Navega a AddProductScreen para EDITAR un producto existente.
  /// Ver nota de BUG CRÍTICO en _navegarAgregarProducto — mismo fix aquí.
  void _navegarEditarProducto(Map<String, dynamic> productoActual) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddProductScreen(
              initialProduct: productoActual,
              onSave: (_) {},
            ),
      ),
    );
  }

  /// Muestra diálogo de confirmación y elimina vía provider.
  void _confirmarEliminar(String productoId) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar este producto?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await context.read<ProductProvider>().deleteProduct(
                      productoId,
                    );
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al eliminar el producto'),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch: reconstruye este widget cuando el provider notifica cambios
    final provider = context.watch<ProductProvider>();
    final productos = provider.productosMap;

    return Scaffold(
      appBar: AppBar(title: const Text('Fresc(o)rden')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 175, 186, 245),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fresc(o)rden',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10.0),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_basket),
              title: Text('Productos (${productos.length})'),
              // PASO 2 — Alertas de Stock mínimo (#2): aviso visible en el
              // drawer cuando hay productos que llegaron a su cantidad mínima.
              subtitle:
                  provider.lowStockCount > 0
                      ? Text(
                        '${provider.lowStockCount} con stock bajo',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : null,
              trailing:
                  provider.lowStockCount > 0
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : null,
              onTap: () async {
                // Capturar el provider ANTES de los awaits
                // (fix use_build_context_synchronously)
                final provider = context.read<ProductProvider>();
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ProductosScreen(
                          productos: productos,
                          onEdit: (index) {
                            _navegarEditarProducto(productos[index]);
                          },
                          onDelete: (index) {
                            final id = productos[index]['id'] as String? ?? '';
                            if (id.isNotEmpty) _confirmarEliminar(id);
                          },
                        ),
                  ),
                );
                // Refresca por si la sub-pantalla cambió algo directamente
                if (mounted) {
                  await provider.loadProducts();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.fastfood),
              title: const Text('Recetas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecetasScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Lista de Compras'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Analíticas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Contacto'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Acerca de'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: cerrarSesion,
            ),
          ],
        ),
      ),
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(150.0),
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.asset('assets/verduras.png'),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      '¡Bienvenido a Fresc(o)rden!',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Textos(),
                ],
              ),
      floatingActionButton: ButtonPlus(
        onManualAdd: () => _navegarAgregarProducto(),
        onBulkAdd: () => _navegarAgregarProducto(isBulkEntry: true),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class Textos extends StatelessWidget {
  const Textos({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX overflow: Row sin Expanded/Flexible desbordaba horizontalmente en
    // pantallas angostas o con escalado de fuente grande ("RIGHT OVERFLOWED
    // BY 197 PIXELS"). Se envuelve en Padding + Flexible en cada Text para
    // que el texto pueda hacer wrap dentro de su espacio disponible en vez
    // de forzar el ancho del Row más allá de la pantalla.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Flexible(child: Text('Da en la  ', textAlign: TextAlign.right)),
          Image.asset('assets/manzana.png', width: 25.0, height: 25.0),
          const SizedBox(width: 3.0),
          const Flexible(
            child: Text(' para agregar un producto', textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }
}
