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
import '../presentation/providers/product_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _productos = List<Map<String, dynamic>>.from(widget.productos);
    _productosFiltrados = List<Map<String, dynamic>>.from(_productos);
  }

  void _mostrarDialogoFiltros() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ordenar por:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                title: const Text('Fecha de expiración (más cercana)'),
                onTap: () {
                  setState(() {
                    _productosFiltrados.sort((a, b) {
                      final da = DateTime.tryParse(
                              a['expirationDate'] ?? '') ??
                          DateTime(9999);
                      final db = DateTime.tryParse(
                              b['expirationDate'] ?? '') ??
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
                      final qa = int.tryParse(
                              a['quantity']?.toString() ?? '0') ??
                          0;
                      final qb = int.tryParse(
                              b['quantity']?.toString() ?? '0') ??
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
                      final qa = int.tryParse(
                              a['quantity']?.toString() ?? '0') ??
                          0;
                      final qb = int.tryParse(
                              b['quantity']?.toString() ?? '0') ??
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
    _productosFiltrados = _productos.where((producto) {
      final nombre = producto['name']?.toString().toLowerCase() ?? '';
      return nombre.contains(_busqueda.toLowerCase());
    }).toList();
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
            child: _productosFiltrados.isEmpty
                ? const Center(child: Text('No hay productos agregados'))
                : RefreshIndicator(
                    onRefresh: _actualizarProductos,
                    child: ListView.builder(
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) =>
                          _buildProductoCard(index),
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
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: (imagePath != null &&
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
        title: Text(
          producto['name']?.toString() ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cantidad: ${producto['quantity'] ?? '-'} '
                '${producto['unit'] ?? ''}'),
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
                    (p) => p['id'] == producto['id']);
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
  /// Muestra cuántos días lleva almacenado el producto.
  /// Solo visible cuando el usuario registró una fecha de almacenamiento.
  Widget _buildStorageLabel(Map<String, dynamic> producto) {
    final storedAtStr = producto['storedAt'] as String?;
    if (storedAtStr == null || storedAtStr.isEmpty) return const SizedBox.shrink();
    final storedAt = DateTime.tryParse(storedAtStr);
    if (storedAt == null) return const SizedBox.shrink();

    final daysStored = DateTime.now().difference(storedAt).inDays;
    final isCritical = daysStored >= 5;

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
            'Almacenado hace $daysStored día${daysStored == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: isCritical ? Colors.deepOrange : Colors.blueGrey,
              fontWeight:
                  isCritical ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isCritical) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber,
                size: 12, color: Colors.deepOrange),
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
              '¿Estás seguro de que quieres eliminar este producto?'),
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
                  await context
                      .read<ProductProvider>()
                      .deleteProduct(productoId);
                  if (!mounted) return;
                  setState(() {
                    _productos.removeWhere((p) => p['id'] == productoId);
                    _productosFiltrados.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Producto eliminado correctamente')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Error al eliminar el producto')),
                  );
                }
              },
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red)),
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
