import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme/app_spacing.dart';
import '../../routes.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../utils/notification_service.dart';
import '../providers/recipe_provider.dart';
import '../providers/restock_prediction_provider.dart';
import '../../domain/entities/restock_prediction.dart';
import '../utils/food_category_ui.dart';
import 'recetas_screen.dart';
import 'detalle_receta_screen.dart';
import 'productos_screen.dart';
import 'add_product_screen.dart';
import '../widgets/button_plus.dart';
import '../widgets/common/custom_card.dart';
import 'login_screen.dart';
import 'shopping_list_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'contact_screen.dart';
import 'about_screen.dart';
import 'household_screen.dart';
import 'assistant_screen.dart';
import 'category_picker_screen.dart';
import 'preset_food_picker_screen.dart';
import 'admin_dashboard_screen.dart';
import 'ai_coming_soon_screen.dart';
import 'home_tutorial_screen.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/preset_food.dart';
import '../../domain/entities/product.dart';
import '../../domain/utils/expiration_alert_policy.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const _tutorialSeenKey = 'home_tutorial_seen';

  @override
  void initState() {
    super.initState();
    // Carga inicial delegada al provider; no hay Firestore directo aquí.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<RecipeProvider>().loadRecipes();
      _requestStartupPermissions();
      _showTutorialIfFirstVisit();
    });
  }

  /// Pide cámara y notificaciones apenas el usuario llega a Inicio, en vez
  /// de dejar que las pida recién cuando use la cámara o registre su primer
  /// producto — así sabe desde el principio si quedaron habilitadas. Si ya
  /// están concedidas o el usuario ya las rechazó antes, el sistema no
  /// vuelve a mostrar el diálogo nativo (no es molesto en visitas futuras).
  Future<void> _requestStartupPermissions() async {
    await Permission.camera.request();
    await NotificationService.instance.initialize();
  }

  Future<void> _showTutorialIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tutorialSeenKey) ?? false) return;
    await prefs.setBool(_tutorialSeenKey, true);
    if (!mounted) return;
    _openTutorial();
  }

  void _openTutorial() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        settings: const RouteSettings(name: AppRoutes.homeTutorial),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const HomeTutorialScreen()),
      ),
    );
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

  Future<void> _navegarAgregarPorCategoria() async {
    final categoria = await Navigator.push<FoodCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryPickerScreen(),
        settings: const RouteSettings(name: AppRoutes.categoryPicker),
      ),
    );
    if (categoria == null || !mounted) return;

    // Paso intermedio: catálogo curado para esa categoría (ver
    // PresetFoodPickerScreen). `null` = canceló con el botón atrás, no
    // avanzar; `manualEntry` = "no lo encuentro", seguir con el formulario
    // en blanco de siempre; cualquier otro valor es el PresetFood elegido.
    final resultado = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => PresetFoodPickerScreen(category: categoria),
        settings: const RouteSettings(name: AppRoutes.presetFoodPicker),
      ),
    );
    if (resultado == null || !mounted) return;
    final preset =
        resultado == PresetFoodPickerScreen.manualEntry
            ? null
            : resultado as PresetFood;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddProductScreen(
              onSave: (_) {},
              initialCategory: categoria,
              initialName: preset?.name,
              initialUnit: preset?.unit,
              hideStorageDate: preset != null,
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
        builder: (_) => AddProductScreen(onSave: (_) {}, isBulkEntry: true),
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

  /// "Agregar de nuevo" desde una predicción de reposición: precarga
  /// nombre, categoría y unidad de la última vez (así el usuario no tiene
  /// que volver a buscarlo en el catálogo ni escribirlo) — solo falta
  /// confirmar cantidad y fecha de vencimiento, que sí cambian cada compra.
  void _navegarAgregarDeNuevo(RestockPrediction prediction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          onSave: (_) {},
          initialCategory: prediction.category,
          initialName: prediction.productName,
          initialUnit: prediction.unit,
        ),
        settings: const RouteSettings(name: AppRoutes.addProduct),
      ),
    );
  }

  void _navegarAProductos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductosScreen(onEdit: _navegarEditarProducto),
        settings: const RouteSettings(name: AppRoutes.productos),
      ),
    );
  }

  List<Product> _expiringSoon(List<Product> products) {
    final now = DateTime.now();
    return products
        .where(
          (p) =>
              ExpirationAlertPolicy.daysLeftInsideWindow(
                p.expirationDate,
                now,
              ) !=
              null,
        )
        .toList();
  }

  /// Dashboard real (vencimientos, stock bajo, receta sugerida) — antes
  /// Inicio era solo un mensaje de bienvenida sin información útil del
  /// hogar. Solo se muestra cuando ya hay inventario; un hogar recién
  /// creado sigue viendo el mensaje de bienvenida de siempre (ver `build`).
  Widget _buildDashboard(
    BuildContext context,
    ProductProvider productProvider,
  ) {
    final recipeProvider = context.watch<RecipeProvider>();
    final inventory = productProvider.products;
    final expiringSoon = _expiringSoon(inventory);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_outlined,
                iconColor: expiringSoon.isEmpty
                    ? colorScheme.primary
                    : colorScheme.error,
                label: 'Vencen pronto',
                value: '${expiringSoon.length}',
                onTap: _navegarAProductos,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: productProvider.lowStockCount == 0
                    ? colorScheme.primary
                    : colorScheme.error,
                label: 'Stock bajo',
                value: '${productProvider.lowStockCount}',
                onTap: _navegarAProductos,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildRestockPredictionsCard(context, inventory),
        const SizedBox(height: AppSpacing.sm),
        _buildSuggestedRecipeCard(recipeProvider, inventory),
      ],
    );
  }

  /// "Se te puede estar acabando X" — basado en cada cuánto el hogar suele
  /// volver a comprar ese producto (ver PredictRestockUseCase), no en IA:
  /// pura aritmética sobre el historial que la app ya guarda.
  Widget _buildRestockPredictionsCard(
    BuildContext context,
    List<Product> inventory,
  ) {
    final predictions = context
        .watch<RestockPredictionProvider>()
        .predict(inventory);
    if (predictions.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final top = predictions.take(3).toList();

    return CustomCard(
      onTap: _navegarAProductos,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: colorScheme.tertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Se te puede estar acabando',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Según cada cuánto sueles comprarlo',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final prediction in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Image.asset(
                    prediction.category.iconAsset,
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      prediction.productName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    'cada ~${prediction.averageCycleDays}d',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Agregar de nuevo',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    onPressed: () => _navegarAgregarDeNuevo(prediction),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return CustomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Mejor coincidencia del catálogo contra el inventario actual — misma
  /// regla que RecetasScreen (RecipeProvider.sortedByMatch), solo que acá
  /// se muestra una sola, como sugerencia del día.
  Widget _buildSuggestedRecipeCard(
    RecipeProvider recipeProvider,
    List<Product> inventory,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (recipeProvider.recipes.isEmpty) return const SizedBox.shrink();

    final receta = recipeProvider.sortedByMatch(inventory).first;
    final faltantes = recipeProvider.missingIngredientsFor(receta, inventory);

    return CustomCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetalleRecetaScreen(receta: receta, faltantes: faltantes),
          settings: const RouteSettings(name: AppRoutes.detalleReceta),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              receta.imagePath,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receta sugerida de hoy',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  receta.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  faltantes.isEmpty
                      ? 'Ya tienes todo lo que necesitas'
                      : 'Te faltan ${faltantes.length} ingrediente'
                          '${faltantes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
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
      appBar: AppBar(
        title: const Text('Fresc(o)rden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ayuda y tutorial de la app',
            onPressed: _openTutorial,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    Color.lerp(
                      colorScheme.primary,
                      colorScheme.tertiary,
                      0.35,
                    )!,
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
                        (_) => ProductosScreen(onEdit: _navegarEditarProducto),
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
            Builder(
              builder: (context) {
                final canUseAi = context.watch<AuthProvider>().canUseLiveAi;
                final colorScheme = Theme.of(context).colorScheme;
                return ListTile(
                  leading: Icon(
                    Icons.smart_toy,
                    color: canUseAi ? null : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Asistente Culinario',
                    style:
                        canUseAi
                            ? null
                            : TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing:
                      canUseAi
                          ? null
                          : Text(
                            'Pronto',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                canUseAi
                                    ? const AssistantScreen()
                                    : const AiComingSoonScreen(
                                      title: 'Asistente Culinario',
                                      description:
                                          'Pronto vas a poder conversar con el '
                                          'asistente de IA sobre tus recetas, '
                                          'conservación de alimentos y cómo usar '
                                          'la app.',
                                    ),
                        settings: const RouteSettings(
                          name: AppRoutes.assistant,
                        ),
                      ),
                    );
                  },
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
            // usuario autenticado es el admin (ver AuthProvider.isAdmin).
            if (context.watch<AuthProvider>().isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Panel Administrativo'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                      settings: const RouteSettings(
                        name: AppRoutes.adminDashboard,
                      ),
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
              : provider.products.isEmpty
              // Hogar recién creado, sin inventario todavía: el dashboard
              // no tendría nada que mostrar, así que se mantiene el
              // mensaje de bienvenida de siempre como guía inicial.
              ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/Frescorden-logo/stickers/sticker-joy.png',
                        width: 180,
                        height: 180,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '¡Bienvenido a Fresc(o)rden!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tu despensa está lista para que empieces a '
                        'organizarla y dejes de desperdiciar comida.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Textos(),
                    ],
                  ),
                ),
              )
              : _buildDashboard(context, provider),
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
          Image.asset(
            'assets/Frescorden-logo/fresco-fresh-512.png',
            width: 25.0,
            height: 25.0,
          ),
          const SizedBox(width: 3.0),
          const Flexible(
            child: Text(' para agregar un producto', textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }
}
