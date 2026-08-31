// lib/screens/productos_screen.dart
//
// BUG #9 CORREGIDO: La pantalla mutaba widget.productos directamente
//   (_actualizarProductos hacía widget.productos.clear() y addAll()).
//   Flutter prohíbe que un widget hijo mute una lista que pertenece al padre;
//   en navegación rápida esto causaba "setState on disposed widget".
//   FIX: Se usa una copia local _productos (inicializada en initState y
//   actualizada en _actualizarProductos) sin tocar nunca widget.productos.
//
// BUG #11 CORREGIDO: El widget leía producto['image'] para mostrar la foto,
//   pero add_product_screen guarda el campo como 'imagePath'. Por eso las
//   imágenes nunca aparecían en la lista.
//   FIX: Se lee 'imagePath' con fallback a 'image' para retrocompatibilidad
//   con documentos existentes en Firestore que puedan tener el campo viejo.
//
// MEJORA: Se reemplaza print() por debugPrint() (el linter lo exige).

// LINT FIX: eliminados 'package:firebase_auth/firebase_auth.dart' (unused_import)
// y el campo 'user' (unused_element). La eliminación de productos ahora
// pasa por ProductProvider que gestiona la autenticación internamente.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/food_category.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/utils/food_category_ui.dart';

class ProductosScreen extends StatefulWidget {
  final List<Map<String, dynamic>> productos;
  final Function(int) onEdit;
  final Function(int) onDelete;

  const ProductosScreen({
    super.key,
    required this.productos,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // BUG #9 FIX: copia local — nunca mutamos widget.productos
  late List<Map<String, dynamic>> _productos;
  List<Map<String, dynamic>> _productosFiltrados = [];
  String _busqueda = '';

  // ─── PASO 2 ─────────────────────────────────────────────────────────────
  FoodCategory? _filtroCategoria; // null = todas las categorías
  bool _soloStockBajo = false;

  @override
  void initState() {
    super.initState();
    _productos = List<Map<String, dynamic>>.from(widget.productos);
    _productosFiltrados = List<Map<String, dynamic>>.from(_productos);
  }

  void _mostrarDialogoFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        // PASO 2: StatefulBuilder para que los chips de categoría y el
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
                  // ── PASO 2: filtro por categoría ──────────────────────────────
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
                          setSheetState(() => _filtroCategoria = null);
                          setState(_actualizarFiltroSinSetState);
                        },
                      ),
                      for (final cat in FoodCategory.values)
                        ChoiceChip(
                          avatar: Icon(cat.icon, size: 16),
                          label: Text(cat.label),
                          selected: _filtroCategoria == cat,
                          onSelected: (_) {
                            setSheetState(() => _filtroCategoria = cat);
                            setState(_actualizarFiltroSinSetState);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── PASO 2: filtro de stock bajo ──────────────────────────────
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo stock bajo'),
                    subtitle: const Text(
                      'Productos que llegaron a su cantidad mínima',
                    ),
                    value: _soloStockBajo,
                    onChanged: (value) {
                      setSheetState(() => _soloStockBajo = value);
                      setState(_actualizarFiltroSinSetState);
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
                      setState(() {
                        _productosFiltrados.sort((a, b) {
                          final da =
                              DateTime.tryParse(a['expirationDate'] ?? '') ??
                              DateTime(9999);
                          final db =
                              DateTime.tryParse(b['expirationDate'] ?? '') ??
                              DateTime(9999);
                          return da.compareTo(db);
                        });
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Cantidad (mayor a menor)'),
                    onTap: () {
                      setState(() {
                        _productosFiltrados.sort((a, b) {
                          final qa =
                              int.tryParse(a['quantity']?.toString() ?? '0') ??
                              0;
                          final qb =
                              int.tryParse(b['quantity']?.toString() ?? '0') ??
                              0;
                          return qb.compareTo(qa);
                        });
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Cantidad (menor a mayor)'),
                    onTap: () {
                      setState(() {
                        _productosFiltrados.sort((a, b) {
                          final qa =
                              int.tryParse(a['quantity']?.toString() ?? '0') ??
                              0;
                          final qb =
                              int.tryParse(b['quantity']?.toString() ?? '0') ??
                              0;
                          return qa.compareTo(qb);
                        });
                      });
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

  // FASE 2: delega la recarga al ProductProvider en lugar de Firestore directo
  // FIX #H3: provider capturado ANTES del await para evitar uso de context
  // en gap asíncrono (use_build_context_synchronously).
  Future<void> _actualizarProductos() async {
    final provider = context.read<ProductProvider>();
    try {
      await provider.loadProducts();
      if (!mounted) return;
      setState(() {
        _productos = provider.productosMap;
        _actualizarFiltroSinSetState();
      });
    } catch (e) {
      debugPrint('Error al actualizar productos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar los productos')),
        );
      }
    }
  }

  // Versión sin setState para llamar desde dentro de otro setState
  void _actualizarFiltroSinSetState() {
    _productosFiltrados =
        _productos.where((producto) {
          final nombre = producto['name']?.toString().toLowerCase() ?? '';
          final coincideBusqueda = nombre.contains(_busqueda.toLowerCase());

          // PASO 2: filtro por categoría
          final coincideCategoria =
              _filtroCategoria == null ||
              FoodCategory.fromName(producto['category'] as String?) ==
                  _filtroCategoria;

          // PASO 2: filtro "solo stock bajo"
          final coincideStock = !_soloStockBajo || _esStockBajo(producto);

          return coincideBusqueda && coincideCategoria && coincideStock;
        }).toList();
  }

  /// PASO 2 — Alertas de Stock mínimo (#2): replica `Product.isLowStock`
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
              onChanged: (value) {
                setState(() {
                  _busqueda = value;
                  _actualizarFiltroSinSetState();
                });
              },
            ),
          ),
          Expanded(
            child:
                _productosFiltrados.isEmpty
                    ? const Center(child: Text('No hay productos agregados'))
                    : RefreshIndicator(
                      onRefresh: _actualizarProductos,
                      child: ListView.builder(
                        itemCount: _productosFiltrados.length,
                        itemBuilder:
                            (context, index) => _buildProductoCard(index),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(int index) {
    final producto = _productosFiltrados[index];
    final String dateStr = producto['expirationDate'] ?? '';
    int daysRemaining = 0;

    try {
      if (dateStr.isNotEmpty) {
        final expDate = DateTime.parse(dateStr);
        daysRemaining = expDate.difference(DateTime.now()).inDays;
      }
    } catch (_) {
      daysRemaining = 0;
    }

    // BUG #11 FIX: leer 'imagePath'; fallback a 'image' para docs existentes
    final String? imagePath =
        producto['imagePath'] as String? ?? producto['image'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        // FIX alineación: con el subtítulo de hasta 4 líneas (categoría +
        // cantidad + vencimiento + badge de trazabilidad a granel), el
        // centrado vertical por defecto de ListTile dejaba la imagen
        // `leading` desalineada respecto al bloque de texto. `top` ancla
        // leading/title/trailing al inicio, consistente sin importar cuántas
        // líneas tenga el subtítulo.
        titleAlignment: ListTileTitleAlignment.top,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
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
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // PASO 2: ícono de la categoría del producto
            Icon(
              FoodCategory.fromName(producto['category'] as String?).icon,
              size: 18,
              color: Colors.blueGrey,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FoodCategory.fromName(producto['category'] as String?).label,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
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
                // PASO 2: badge de stock bajo
                if (_esStockBajo(producto)) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 2),
                  const Text(
                    'Stock bajo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              daysRemaining < 0
                  ? 'Estado: Vencido'
                  : 'Expira en: $daysRemaining días',
              style: TextStyle(color: _getExpirationColor(daysRemaining)),
            ),
            // FASE 3: trazabilidad de perecederos a granel
            _buildStorageLabel(producto),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // Buscamos el índice en la lista original del padre
                final idxOriginal = widget.productos.indexWhere(
                  (p) => p['id'] == producto['id'],
                );
                widget.onEdit(idxOriginal != -1 ? idxOriginal : index);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _eliminarProductoConConfirmacion(index),
            ),
          ],
        ),
      ),
    );
  }

  /// FASE 3: Etiqueta de trazabilidad de perecederos a granel.
  /// Muestra cuántos días lleva almacenado el producto. Solo visible para
  /// productos registrados como "a granel" (isBulk) — entryDate ahora es
  /// obligatoria para TODOS los productos, así que gatear por isBulk evita
  /// mostrar "Almacenado hace 0 días" en cada producto empacado recién
  /// agregado (dato sin valor informativo fuera del caso de granel).
  Widget _buildStorageLabel(Map<String, dynamic> producto) {
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

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            Icons.kitchen,
            size: 12,
            color: isCritical ? Colors.deepOrange : Colors.blueGrey,
          ),
          const SizedBox(width: 4),
          Text(
            'Almacenado hace $daysInStorage día${daysInStorage == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: isCritical ? Colors.deepOrange : Colors.blueGrey,
              fontWeight: isCritical ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isCritical) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber, size: 12, color: Colors.deepOrange),
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

  void _eliminarProductoConConfirmacion(int index) {
    final producto = _productosFiltrados[index];
    final productoId = producto['id'] as String?;

    if (productoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no tiene un ID válido')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
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
                // FASE 2: delega eliminación al ProductProvider
                try {
                  await context.read<ProductProvider>().deleteProduct(
                    productoId,
                  );
                  if (!mounted) return;
                  setState(() {
                    _productos.removeWhere((p) => p['id'] == productoId);
                    _productosFiltrados.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto eliminado correctamente'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al eliminar el producto'),
                    ),
                  );
                }
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getExpirationColor(int daysRemaining) {
    if (daysRemaining < 0) return Colors.red;
    if (daysRemaining <= 3) return Colors.orange;
    return Colors.green;
  }
}
