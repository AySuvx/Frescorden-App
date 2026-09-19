import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/theme/app_spacing.dart';
import '../../routes.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import 'recetas_screen.dart';
import 'productos_screen.dart';
import 'add_product_screen.dart';
import '../widgets/button_plus.dart';
import 'login_screen.dart';
import 'shopping_list_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'contact_screen.dart';
import 'about_screen.dart';
import 'household_screen.dart';
import 'assistant_screen.dart';
import 'category_picker_screen.dart';
import 'admin_dashboard_screen.dart';
import '../../domain/entities/food_category.dart';

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
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: const RouteSettings(name: AppRoutes.login),
        ),
        (route) => false,
      );
    }
  }


  /// Flujo "Por Categoría" de la manzanita: primero el selector de
  /// categorías (CategoryPickerScreen), después el formulario estándar con
  /// esa categoría ya preseleccionada. Si el usuario vuelve atrás sin
  /// elegir ninguna, no se abre el formulario.
  Future<void> _navegarAgregarPorCategoria() async {
    final categoria = await Navigator.push<FoodCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryPickerScreen(),
        settings: const RouteSettings(name: AppRoutes.categoryPicker),
      ),
    );
    if (categoria == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddProductScreen(
              onSave: (_) {},
              isManualAdd: true,
              initialCategory: categoria,
            ),
        settings: const RouteSettings(name: AppRoutes.addProduct),
      ),
    );
  }

  /// Flujo "A Granel" de la manzanita: mismo formulario, sin paso de
  /// selección de categoría — va directo con isBulkEntry: true.
  void _navegarAgregarAGranel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddProductScreen(
              onSave: (_) {},
              isManualAdd: true,
              isBulkEntry: true,
            ),
        settings: const RouteSettings(name: AppRoutes.addProduct),
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
        settings: const RouteSettings(name: AppRoutes.addProduct),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch: reconstruye este widget cuando el provider notifica cambios
    final provider = context.watch<ProductProvider>();
    final productos = provider.productosMap;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fresc(o)rden')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              // Degradado suave dentro de la propia paleta orgánica:
              // primary → una mezcla hacia tertiary (Ámbar), no
              // primary→primaryContainer — ese salto es
              // demasiado grande en luminosidad y dejaría "onPrimary" sin
              // contraste garantizado en el extremo claro del degradado.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.35)!,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fresc(o)rden',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
              // Aviso visible en el drawer cuando hay productos que
              // llegaron a su cantidad mínima.
              subtitle:
                  provider.lowStockCount > 0
                      ? Text(
                        '${provider.lowStockCount} con stock bajo',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : null,
              trailing:
                  provider.lowStockCount > 0
                      ? Icon(Icons.error_outline, color: colorScheme.error)
                      : null,
              onTap: () {
                // ProductosScreen ahora es reactiva (context.watch<ProductProvider>()
                // internamente) — ya no necesita un snapshot por constructor
                // ni un refresh manual al volver.
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ProductosScreen(
                          onEdit: _navegarEditarProducto,
                        ),
                    settings: const RouteSettings(name: AppRoutes.productos),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_filled),
              title: const Text('Mi Hogar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HouseholdScreen(),
                    settings: const RouteSettings(name: AppRoutes.household),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('Asistente Culinario'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssistantScreen(),
                    settings: const RouteSettings(name: AppRoutes.assistant),
                  ),
                );
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
                    settings: const RouteSettings(name: AppRoutes.recetas),
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
                  MaterialPageRoute(
                    builder: (_) => const ShoppingListScreen(),
                    settings: const RouteSettings(name: AppRoutes.shoppingList),
                  ),
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
                  MaterialPageRoute(
                    builder: (_) => const AnalyticsScreen(),
                    settings: const RouteSettings(name: AppRoutes.analytics),
                  ),
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
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                    settings: const RouteSettings(name: AppRoutes.settings),
                  ),
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
                  MaterialPageRoute(
                    builder: (_) => const ContactScreen(),
                    settings: const RouteSettings(name: AppRoutes.contact),
                  ),
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
                  MaterialPageRoute(
                    builder: (_) => const AboutScreen(),
                    settings: const RouteSettings(name: AppRoutes.about),
                  ),
                );
              },
            ),
            // Entrada al Panel Administrativo, visible únicamente si el
            // usuario autenticado es el admin (ver kAdminUid).
            if (context.watch<AuthProvider>().currentUser?.uid == kAdminUid)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Panel Administrativo'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                      settings: const RouteSettings(name: AppRoutes.adminDashboard),
                    ),
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
        onManualAdd: _navegarAgregarPorCategoria,
        onBulkAdd: _navegarAgregarAGranel,
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
