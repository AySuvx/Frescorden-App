// Destino del ítem "Asistente Culinario" del menú para cualquier usuario
// que no sea el admin (ver AuthProvider.isAdmin) mientras la cuota gratuita
// compartida de Gemini está restringida. Reemplaza la navegación real a
// AssistantScreen — no un candado ni un error, una vista previa honesta.

import 'package:flutter/material.dart';

import '../widgets/common/ai_coming_soon_card.dart';

class AiComingSoonScreen extends StatelessWidget {
  const AiComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AiComingSoonCard(title: title, description: description),
          ),
        ),
      ),
    );
  }
}
