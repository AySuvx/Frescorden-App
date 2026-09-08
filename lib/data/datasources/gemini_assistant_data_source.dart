// google_generative_ai está deprecado (Google no lo actualiza más) y su
// reemplazo oficial es firebase_ai, que además reutiliza el proyecto
// Firebase ya configurado en la app (sin API key propia del cliente).
// Requiere habilitar "Gemini API" en la consola de Firebase del proyecto.
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
''';

// gemini-1.5/2.0 fueron retirados (dan 404); esta es la versión estable
// vigente según la documentación oficial de Firebase AI Logic.
const _modelName = 'gemini-3.5-flash';
const _maxInventoryItems = 20;

class GeminiAssistantDataSource {
  final GenerativeModel _model;
  ChatSession? _chat;

  GeminiAssistantDataSource()
      : _model = FirebaseAI.googleAI().generativeModel(
          model: _modelName,
          systemInstruction: Content.system(_systemInstruction),
        );

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
