
// lib/utils/product_utils.dart

/// Agrega o actualiza un producto dentro de una lista de productos.
/// Si encuentra un producto con el mismo código de barras, actualiza la cantidad.
/// Si no existe, lo agrega.
Map<String, dynamic> agregarOActualizarProducto(
  List<Map<String, dynamic>> productos,
  Map<String, dynamic> nuevoProducto,
) {
  final barcode = nuevoProducto['barcode'];
  String cantidadStr = nuevoProducto['quantity'] ?? '0';

  // Verificar si la cantidad es numérica; si no, usar 0
  final cantidad = int.tryParse(cantidadStr) ?? 0;

  // Buscar el índice del producto existente
  final index = productos.indexWhere((producto) => producto['barcode'] == barcode);

  if (index != -1) {
    // Ya existe: actualizar la cantidad
    final productoExistente = productos[index];
    final cantidadExistente = int.tryParse(productoExistente['quantity'].toString()) ?? 0;
    final nuevaCantidad = cantidadExistente + cantidad;
    productos[index]['quantity'] = nuevaCantidad.toString();
    return productos[index];
  } else {
    // No existe: agregar nuevo producto
    final nuevo = Map<String, dynamic>.from(nuevoProducto);
    nuevo['quantity'] = cantidad.toString(); // Asegurar formato numérico
    productos.add(nuevo);
    return nuevo;
  }
}
