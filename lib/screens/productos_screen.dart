// lib/screens/productos_screen.dart
//
// BUG #11 CORREGIDO: El widget leía producto['image'] para mostrar la foto,
//   pero add_product_screen guarda el campo como 'imagePath'. Por eso las
//   imágenes nunca aparecían en la lista.
//   FIX: Se lee 'imagePath' con fallback a 'image' para retrocompatibilidad
//   con documentos existentes en Firestore que puedan tener el campo viejo.
//
// Reactividad en tiempo real (Household):
// Antes, esta pantalla recibía `productos` como snapshot fijo por
// constructor (copiado a un campo local `_productos` en initState) y solo
// se refrescaba manualmente al volver de una sub-pantalla
// (`_actualizarProductos`). Con el inventario ahora sincronizado por
// stream (ver ProductProvider.setActiveHousehold), esa copia local quedaba
// obsoleta apenas otro miembro del hogar editaba algo mientras esta
// pantalla seguía abierta.
// FIX: se elimina el constructor `productos` y la copia local — el build()
// lee `context.watch<ProductProvider>().productosMap` directo, así que
// cualquier cambio (propio o de otro dispositivo del hogar) reconstruye la
// lista sola. Filtro/búsqueda/orden pasan a ser criterios persistentes
// (campos de estado) que se reaplican en cada build sobre los datos
// frescos del provider, en vez de mutar una lista guardada una sola vez.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme/app_spacing.dart';
import '../domain/entities/food_category.dart';
import '../domain/entities/product_history_entry.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/utils/food_category_ui.dart';
import '../presentation/widgets/common/custom_card.dart';
import '../presentation/widgets/common/glass_dialog.dart';
import '../presentation/widgets/common/skeleton_loader.dart';
import '../presentation/widgets/common/status_badge.dart';

enum _SortOption { expirationAsc, quantityDesc, quantityAsc }

class ProductosScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> producto) onEdit;

  const ProductosScreen({super.key, required this.onEdit});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  String _busqueda = '';
  FoodCategory? _filtroCategoria; // null = todas las categorías
  bool _soloStockBajo = false;
  _SortOption? _sortOption; // null = orden natural (el que entrega el stream)

  void _mostrarDialogoFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        // StatefulBuilder para que los chips de categoría y el
        // switch de "solo stock bajo" respondan al toque dentro de la
        // misma hoja, sin cerrarla (a diferencia de las opciones de orden).
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── filtro por categoría ──────────────────────────────
                  const Text(
                    'Categoría:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _filtroCategoria == null,
                        onSelected: (_) {
                          HapticFeedback.lightImpact();
                          setSheetState(() => _filtroCategoria = null);
                          setState(() {});
                        },
                      ),
                      for (final cat in FoodCategory.values)
                        ChoiceChip(
                          avatar: Icon(cat.icon, size: 16),
                          label: Text(cat.label),
                          selected: _filtroCategoria == cat,
                          onSelected: (_) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => _filtroCategoria = cat);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── filtro de stock bajo ──────────────────────────────
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo stock bajo'),
                    subtitle: const Text(
                      'Productos que llegaron a su cantidad mínima',
                    ),
                    value: _soloStockBajo,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      setSheetState(() => _soloStockBajo = value);
                      setState(() {});
                    },
                  ),
                  const Divider(),

                  const Text(
                    'Ordenar por:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ListTile(
                    title: const Text('Fecha de expiración (más cercana)'),
                    onTap: () {
                      setState(() => _sortOption = _SortOption.expirationAsc);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Cantidad (mayor a menor)'),
                    onTap: () {
                      setState(() => _sortOption = _SortOption.quantityDesc);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Cantidad (menor a mayor)'),
                    onTap: () {
                      setState(() => _sortOption = _SortOption.quantityAsc);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Aplica búsqueda + filtros + orden (criterios persistentes en el
  /// estado) sobre los datos frescos del provider. Se recalcula en cada
  /// build — barato: son listas de inventario doméstico, no miles de ítems.
  List<Map<String, dynamic>> _filtrarYOrdenar(
    List<Map<String, dynamic>> productos,
  ) {
    final filtrados =
        productos.where((producto) {
          final nombre = producto['name']?.toString().toLowerCase() ?? '';
          final coincideBusqueda = nombre.contains(_busqueda.toLowerCase());

          final coincideCategoria =
              _filtroCategoria == null ||
              FoodCategory.fromName(producto['category'] as String?) ==
                  _filtroCategoria;

          final coincideStock = !_soloStockBajo || _esStockBajo(producto);

          return coincideBusqueda && coincideCategoria && coincideStock;
        }).toList();

    switch (_sortOption) {
      case _SortOption.expirationAsc:
        filtrados.sort((a, b) {
          final da =
              DateTime.tryParse(a['expirationDate'] ?? '') ?? DateTime(9999);
          final db =
              DateTime.tryParse(b['expirationDate'] ?? '') ?? DateTime(9999);
          return da.compareTo(db);
        });
      case _SortOption.quantityDesc:
        filtrados.sort((a, b) {
          final qa = int.tryParse(a['quantity']?.toString() ?? '0') ?? 0;
          final qb = int.tryParse(b['quantity']?.toString() ?? '0') ?? 0;
          return qb.compareTo(qa);
        });
      case _SortOption.quantityAsc:
        filtrados.sort((a, b) {
          final qa = int.tryParse(a['quantity']?.toString() ?? '0') ?? 0;
          final qb = int.tryParse(b['quantity']?.toString() ?? '0') ?? 0;
          return qa.compareTo(qb);
        });
      case null:
        break;
    }
    return filtrados;
  }

  /// Alertas de Stock mínimo (#2): replica `Product.isLowStock`
  /// sobre el formato Map que usan las pantallas.
  bool _esStockBajo(Map<String, dynamic> producto) {
    final minStock = producto['minStock'];
    if (minStock == null) return false;
    final min = minStock is int ? minStock : int.tryParse(minStock.toString());
    if (min == null) return false;
    final qty = int.tryParse(producto['quantity']?.toString() ?? '') ?? 0;
    return qty <= min;
  }

  @override
  Widget build(BuildContext context) {
    // watch: reconstruye esta pantalla cuando el inventario del hogar
    // cambia — propio o de cualquier otro miembro, desde cualquier
    // dispositivo (ver ProductProvider.setActiveHousehold).
    final provider = context.watch<ProductProvider>();
    final productos = provider.productosMap;
    final productosFiltrados = _filtrarYOrdenar(productos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos Agregados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _mostrarDialogoFiltros,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _busqueda = value),
            ),
          ),
          Expanded(
            child:
                provider.isLoading
                    // Skeleton en vez de spinner: anticipa la forma real
                    // de las tarjetas — evita además el parpadeo de "No hay
                    // productos agregados" antes de que llegue el primer
                    // snapshot de Firestore.
                    ? const SkeletonLoader()
                    : productosFiltrados.isEmpty
                    ? const Center(child: Text('No hay productos agregados'))
                    : ListView.builder(
                      // Scroll elástico estilo iOS.
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: productosFiltrados.length,
                      itemBuilder:
                          (context, index) => _FadeSlideIn(
                            index: index,
                            child: _buildProductoCard(
                              context,
                              productosFiltrados[index],
                            ),
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(BuildContext context, Map<String, dynamic> producto) {
    final colorScheme = Theme.of(context).colorScheme;
    final String dateStr = producto['expirationDate'] ?? '';
    // null = sin fecha de vencimiento registrada (frecuente en productos a
    // granel) — distinto de "vence hoy" (0), que antes se mostraba por error
    // cuando el campo simplemente no existía.
    int? daysRemaining;

    try {
      if (dateStr.isNotEmpty) {
        final expDate = DateTime.parse(dateStr);
        daysRemaining = expDate.difference(DateTime.now()).inDays;
      }
    } catch (_) {
      daysRemaining = null;
    }

    // BUG #11 FIX: leer 'imagePath'; fallback a 'image' para docs existentes
    final String? imagePath =
        producto['imagePath'] as String? ?? producto['image'] as String?;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      child: ListTile(
        // FIX alineación: con el subtítulo de hasta 4 líneas (categoría +
        // cantidad + vencimiento + badge de trazabilidad a granel), el
        // centrado vertical por defecto de ListTile dejaba la imagen
        // `leading` desalineada respecto al bloque de texto. `top` ancla
        // leading/title/trailing al inicio, consistente sin importar cuántas
        // líneas tenga el subtítulo.
        titleAlignment: ListTileTitleAlignment.top,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child:
              (imagePath != null &&
                      imagePath.isNotEmpty &&
                      File(imagePath).existsSync())
                  ? Image.file(
                    File(imagePath),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderIcon(),
                  )
                  : _placeholderIcon(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                producto['name']?.toString() ?? 'Sin nombre',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ícono de la categoría del producto
            Icon(
              FoodCategory.fromName(producto['category'] as String?).icon,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FoodCategory.fromName(producto['category'] as String?).label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                // FIX overflow: sin Flexible, "Cantidad: N unidad" + el
                // badge de stock bajo podían exceder el ancho disponible del
                // subtítulo (acotado por leading + trailing del ListTile).
                Flexible(
                  child: Text(
                    'Cantidad: ${producto['quantity'] ?? '-'} '
                    '${producto['unit'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // badge de stock bajo
                if (_esStockBajo(producto)) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.error_outline, size: 14, color: colorScheme.error),
                  const SizedBox(width: 2),
                  Text(
                    'Stock bajo',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child:
                  daysRemaining == null
                      ? Text(
                        'Sin fecha de vencimiento',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      )
                      : StatusBadge(
                        status: ProductFreshness.fromDaysRemaining(
                          daysRemaining,
                        ),
                        label:
                            daysRemaining < 0
                                ? 'Vencido'
                                : 'Expira en: $daysRemaining días',
                      ),
            ),
            // trazabilidad de perecederos a granel
            _buildStorageLabel(producto, colorScheme),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.primary),
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onEdit(producto);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: () {
                HapticFeedback.lightImpact();
                _eliminarProductoConConfirmacion(producto);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Etiqueta de trazabilidad de perecederos a granel.
  /// Muestra cuántos días lleva almacenado el producto. Solo visible para
  /// productos registrados como "a granel" (isBulk) — entryDate ahora es
  /// obligatoria para TODOS los productos, así que gatear por isBulk evita
  /// mostrar "Almacenado hace 0 días" en cada producto empacado recién
  /// agregado (dato sin valor informativo fuera del caso de granel).
  Widget _buildStorageLabel(
    Map<String, dynamic> producto,
    ColorScheme colorScheme,
  ) {
    final isBulk = producto['isBulk'] as bool? ?? false;
    if (!isBulk) return const SizedBox.shrink();

    final entryDateStr = producto['entryDate'] as String?;
    if (entryDateStr == null || entryDateStr.isEmpty) {
      return const SizedBox.shrink();
    }
    final entryDate = DateTime.tryParse(entryDateStr);
    if (entryDate == null) return const SizedBox.shrink();

    final daysInStorage = DateTime.now().difference(entryDate).inDays;
    final isCritical = daysInStorage >= 5;
    final color = isCritical ? colorScheme.tertiary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(Icons.kitchen, size: 12, color: color),
          const SizedBox(width: AppSpacing.xs),
          // FIX overflow (hallado en prueba manual en dispositivo,
          // "RenderFlex overflowed by 14 pixels"): mismo patrón que la fila de
          // Cantidad — sin Flexible, el ancho acotado por leading+trailing
          // del ListTile no alcanzaba para el texto completo.
          Flexible(
            child: Text(
              'Almacenado hace $daysInStorage día${daysInStorage == 1 ? '' : 's'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isCritical ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isCritical) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.warning_amber, size: 12, color: color),
          ],
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Image.asset(
      'assets/camaras.png',
      width: 50,
      height: 50,
      fit: BoxFit.cover,
    );
  }

  /// Trazabilidad de Desperdicio vs. Consumo: al
  /// retirar un producto del inventario, quien lo hace declara
  /// explícitamente si lo aprovechó o lo desperdició — ya no se infiere en
  /// silencio comparando la fecha de vencimiento. Esa elección viaja como
  /// [ProductOutcome] al historial y al log de actividad del hogar (ver
  /// ProductProvider.deleteProduct).
  void _eliminarProductoConConfirmacion(Map<String, dynamic> producto) {
    final productoId = producto['id'] as String?;

    if (productoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no tiene un ID válido')),
      );
      return;
    }

    final nombre = producto['name']?.toString() ?? 'este producto';
    final colorScheme = Theme.of(context).colorScheme;

    showGlassDialog(
      context: context,
      title: 'Retirar producto',
      content: Text(
        '¿Qué pasó con "$nombre"? Esto queda registrado en tu '
        'historial y en las analíticas del hogar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _resolverProducto(context, productoId, ProductOutcome.expired);
          },
          child: Text(
            'Desperdiciado / Botado',
            style: TextStyle(color: colorScheme.tertiary),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _resolverProducto(
              context,
              productoId,
              ProductOutcome.consumedOnTime,
            );
          },
          child: Text(
            'Consumido',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  /// Ejecuta la eliminación con el [outcome] elegido en el diálogo (ver
  /// _eliminarProductoConConfirmacion) y cierra el diálogo primero — mismo
  /// orden que el resto de la app para no dejar el diálogo abierto mientras
  /// se espera la respuesta de Firestore.
  Future<void> _resolverProducto(
    BuildContext dialogContext,
    String productoId,
    ProductOutcome outcome,
  ) async {
    Navigator.of(dialogContext).pop();
    // delega eliminación al ProductProvider — la lista se actualiza sola
    // vía el stream, no hace falta setState.
    try {
      await context.read<ProductProvider>().deleteProduct(
        productoId,
        outcome: outcome,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome == ProductOutcome.consumedOnTime
                ? 'Producto marcado como consumido'
                : 'Producto marcado como desperdiciado',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar el producto')),
      );
    }
  }
}

/// Entrada progresiva (fade + slide) para cada tarjeta de la lista.
/// El desfase por índice (40ms por ítem, tope en 300ms)
/// da el efecto "stagger" sin animar decenas de tarjetas a la vez cuando el
/// inventario es grande. Sin key explícita: en una reconstrucción trivial
/// del stream (p. ej. otro miembro del hogar edita un producto) Flutter
/// reutiliza el State existente en esa posición y NO vuelve a animar —
/// solo se re-dispara cuando el ítem es realmente nuevo en el árbol.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
