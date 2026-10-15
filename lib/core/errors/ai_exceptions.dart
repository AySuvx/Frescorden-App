// Subtipo de DomainException para la IA (asistente y receta con IA
// comparten el mismo backend de Gemini — ver GeminiAssistantDataSource).
// Traduce el QuotaExceeded de firebase_ai (cuota gratuita del proyecto de
// Firebase agotada, un límite de Google, no del dispositivo del usuario)
// para que Presentation nunca capture un tipo de excepción de Firebase.

import 'domain_exception.dart';

/// La cuota gratuita compartida del proyecto (Gemini Developer API) se
/// agotó por hoy — no es la cuota local de 20/día por dispositivo
/// (QuotaService), que es un límite aparte y se agota antes que este.
class AiQuotaExceededException extends DomainException {
  const AiQuotaExceededException()
    : super(
        'El asistente de IA alcanzó su límite de uso por ahora. '
        'Vuelve a intentarlo en un rato.',
      );
}
