import 'dart:typed_data';

import '../../domain/entities/food_category.dart';
import '../../domain/entities/product_recognition_result.dart';
import '../../domain/repositories/i_product_recognition_repository.dart';
import '../datasources/gemini_product_recognition_data_source.dart';

class ProductRecognitionRepositoryImpl
    implements IProductRecognitionRepository {
  final GeminiProductRecognitionDataSource _dataSource;

  ProductRecognitionRepositoryImpl(this._dataSource);

  @override
  Future<ProductRecognitionResult> recognizeProduct(
    Uint8List imageBytes,
  ) async {
    final json = await _dataSource.recognizeProduct(imageBytes);
    return ProductRecognitionResult(
      name: json['nombre'] as String? ?? 'Producto no identificado',
      category: FoodCategory.fromName(json['categoria'] as String?),
      unit: json['unidad'] as String? ?? 'unidad',
    );
  }
}
