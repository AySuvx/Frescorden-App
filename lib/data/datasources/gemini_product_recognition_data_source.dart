// Mismo criterio que GeminiAssistantDataSource._recipeModel: una llamada
// = un resultado (sin conversación), con `responseSchema` para forzar
// JSON estructurado en vez de parsear texto libre. La diferencia acá es
// que el prompt incluye una imagen (InlineDataPart) además de texto —
// ver documentación oficial de firebase_ai para InlineDataPart/Content.multi.
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../domain/entities/food_category.dart';

const _visionSystemInstruction = '''
Eres un identificador de productos de supermercado para una app de
inventario de alimentos del hogar. Te muestran la foto de un producto
(empaque, fruta, verdura, etc.) y debes identificar tres cosas: su nombre
genérico y corto, SIN marca comercial (ej. "Leche entera", no "Leche
Alquería Deslactosada 1100ml"); la categoría de alimento que mejor le
corresponde; y la unidad más natural para medirlo en un inventario
doméstico. Si la imagen no muestra un alimento reconocible, usa "Producto
no identificado" como nombre y la categoría "otros".
''';

const _modelName = 'gemini-3.5-flash';

// Misma lista de unidades que ofrece el formulario (ver AddProductScreen)
// — se duplica a propósito en vez de importar desde presentation: el
// dominio de "qué es una unidad válida" es simple y estable, y esta capa
// no debe depender de la UI para saberlo.
const _validUnits = ['unidad', 'kg', 'g', 'L', 'ml', 'lbs', 'oz'];

class GeminiProductRecognitionDataSource {
  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_visionSystemInstruction),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'nombre': Schema.string(
            description: 'Nombre genérico y corto del producto, sin marca',
          ),
          'categoria': Schema.enumString(
            enumValues: FoodCategory.selectable.map((c) => c.name).toList(),
            description: 'Categoría de alimento que mejor corresponde',
          ),
          'unidad': Schema.enumString(
            enumValues: _validUnits,
            description: 'Unidad más natural para medir este producto',
          ),
        },
      ),
    ),
  );

  /// Analiza [imageBytes] (JPEG) y devuelve el JSON crudo
  /// {nombre, categoria, unidad}. Ver ProductRecognitionRepositoryImpl
  /// para el mapeo a la entidad de dominio.
  Future<Map<String, dynamic>> recognizeProduct(Uint8List imageBytes) async {
    final response = await _model.generateContent([
      Content.multi([
        TextPart('Identifica este producto de supermercado.'),
        InlineDataPart('image/jpeg', imageBytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw StateError('Gemini no devolvió una respuesta.');
    }

    // Deserialización defensiva — mismo criterio que
    // GeminiAssistantDataSource.generateColombianRecipe: `responseSchema`
    // fuerza el formato en la mayoría de los casos, pero no lo garantiza.
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException(
        'Gemini devolvió una respuesta que no es JSON válido: ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Gemini devolvió una respuesta con formato inesperado (no es un objeto JSON).',
      );
    }
    return decoded;
  }
}
