import 'dart:typed_data';

import '../entities/product_recognition_result.dart';

abstract interface class IProductRecognitionRepository {
  /// Analiza la foto [imageBytes] (JPEG) y sugiere nombre, categoría y
  /// unidad del producto fotografiado. Lanza si el reconocimiento falla
  /// (sin conexión, respuesta inválida, etc.) — quien llama decide cómo
  /// mostrarlo (ver AddProductScreen).
  Future<ProductRecognitionResult> recognizeProduct(Uint8List imageBytes);
}
