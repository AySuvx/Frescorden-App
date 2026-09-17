// google_generative_ai está deprecado (Google no lo actualiza más) y su
// reemplazo oficial es firebase_ai, que además reutiliza el proyecto
// Firebase ya configurado en la app (sin API key propia del cliente).
// Requiere habilitar "Gemini API" en la consola de Firebase del proyecto.
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../../domain/entities/product.dart';

const _systemInstruction = '''
Eres el asistente culinario de Frescorden. Respondes únicamente sobre:
recetas con los alimentos disponibles, conservación y empaque de alimentos,
reducción de desperdicio, y cómo usar las funciones de la app.
Si te preguntan algo fuera de ese ámbito, redirige la conversación con
amabilidad hacia estos temas. Responde en español, breve y práctico.

Cuando sugieras una receta, usa siempre esta estructura:
**Nombre de la receta**
**Ingredientes de tu inventario:** (los que ya tiene el usuario)
**Ingredientes adicionales:** (los que necesitaría comprar)
**Pasos:** (breves, numerados)

Al final de CADA receta que sugieras, en su propia línea, agrega siempre
este enlace en formato Markdown (sin excepciones, incluso si sugieres
varias recetas en la misma respuesta — una línea de enlace por receta):
[Ver preparación en YouTube](https://www.youtube.com/results?search_query=Receta+NombreDeLaReceta)
Reemplaza "NombreDeLaReceta" por el nombre real de la receta, con espacios
reemplazados por "+" y sin tildes ni caracteres especiales (ej. una receta
llamada "Arroz con Pollo" da como resultado
https://www.youtube.com/results?search_query=Receta+Arroz+con+Pollo).
''';

// gemini-1.5/2.0 fueron retirados (dan 404); esta es la versión estable
// vigente según la documentación oficial de Firebase AI Logic.
const _modelName = 'gemini-3.5-flash';
const _maxInventoryItems = 20;

// Fallback dinámico de recetas: instrucción y esquema
// separados del asistente conversacional de arriba. Este modelo NO
// mantiene una conversación (una llamada = una receta) y fuerza salida
// JSON estricta vía `responseSchema`, para poder parsearla directo a
// [Recipe] sin depender de que el modelo "se acuerde" del formato pedido
// en un prompt de texto libre (el criterio que sí usa el chat de arriba).
const _recipeSystemInstruction = '''
Eres un chef experto en cocina colombiana casera y sencilla, del día a día
(no gourmet ni con ingredientes difíciles de conseguir en Colombia).
Cuando te pidan una receta, responde con una receta colombiana realista,
priorizando los ingredientes del inventario que te compartan — si falta
algún ingrediente típico imprescindible, inclúyelo igual, el usuario podrá
comprarlo. Los pasos deben ser breves, claros y numerados en el orden de
preparación.
''';

class GeminiAssistantDataSource {
  final GenerativeModel _model;
  ChatSession? _chat;

  late final GenerativeModel _recipeModel = FirebaseAI.googleAI().generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_recipeSystemInstruction),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'nombre': Schema.string(description: 'Nombre de la receta'),
          'personas': Schema.integer(description: 'Porciones, típicamente entre 2 y 6'),
          'tiempo_minutos': Schema.integer(
            description: 'Tiempo total de preparación en minutos',
          ),
          'ingredientes': Schema.array(
            items: Schema.object(
              properties: {
                'nombre': Schema.string(),
                'cantidad': Schema.number(),
                'unidad': Schema.string(
                  description: 'Ej: gramos, ml, unidades, tazas, dientes',
                ),
              },
            ),
          ),
          'pasos': Schema.array(
            items: Schema.string(description: 'Un paso de preparación, breve'),
          ),
        },
      ),
    ),
  );

  GeminiAssistantDataSource()
      : _model = FirebaseAI.googleAI().generativeModel(
          model: _modelName,
          systemInstruction: Content.system(_systemInstruction),
        );

  /// Genera una receta colombiana estructurada priorizando [inventory].
  /// Devuelve el JSON crudo con las mismas claves que
  /// `assets/data/recetas.json` (sin `id` ni `imagen`: esos los asigna la
  /// capa de datos, ver RecipeRepositoryImpl.generateAiRecipe).
  Future<Map<String, dynamic>> generateColombianRecipe(
    List<Product> inventory,
  ) async {
    final prompt =
        'Crea una receta colombiana casera y sencilla usando '
        'prioritariamente estos ingredientes disponibles en el hogar:\n'
        '${_inventoryContext(inventory)}';

    final response = await _recipeModel.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw StateError('Gemini no devolvió una receta.');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<String> sendMessage({
    required String prompt,
    List<Product>? currentInventory,
  }) async {
    final fullPrompt = currentInventory == null
        ? prompt
        : '${_inventoryContext(currentInventory)}\n\nConsulta: $prompt';

    // Se deja propagar cualquier excepción (antes se atrapaba acá y se
    // devolvía un mensaje amigable como si fuera una respuesta real —
    // eso le ocultaba a AssistantProvider si la consulta falló, y con la
    // cuota diaria necesita saberlo para NO descontarla en un fallo de
    // red). El mensaje amigable ahora se arma en AssistantProvider.
    _chat ??= _model.startChat();
    final response = await _chat!.sendMessage(Content.text(fullPrompt));
    return response.text ?? 'No obtuve una respuesta. Intenta de nuevo.';
  }

  void resetConversation() => _chat = null;

  // Prioridad: primero lo que vence antes (daysToExpiration ascendente);
  // sin fecha de vencimiento pero a granel, lo que lleva más tiempo
  // almacenado (daysInStorage descendente); todo lo demás, al final.
  int _priorityKey(Product p) {
    final daysToExp = p.daysToExpiration;
    if (daysToExp != null) return daysToExp;
    if (p.isBulk) return -p.daysInStorage;
    return 1 << 30;
  }

  String _inventoryContext(List<Product> inventory) {
    if (inventory.isEmpty) return 'El inventario del hogar está vacío.';

    final sorted = [...inventory]
      ..sort((a, b) => _priorityKey(a).compareTo(_priorityKey(b)));

    final lines = sorted.take(_maxInventoryItems).map((p) {
      final daysToExp = p.daysToExpiration;
      final String when;
      if (daysToExp != null) {
        when = daysToExp < 0
            ? 'vencido hace ${-daysToExp} días'
            : 'vence en $daysToExp días';
      } else if (p.isBulk) {
        when = 'a granel, almacenado hace ${p.daysInStorage} días';
      } else {
        when = 'sin fecha de vencimiento';
      }
      return '- ${p.name}: ${p.quantity} ${p.unit}, $when';
    }).join('\n');

    return 'Inventario disponible (priorizado por lo que vence antes o '
        'lleva más tiempo almacenado):\n$lines';
  }
}
