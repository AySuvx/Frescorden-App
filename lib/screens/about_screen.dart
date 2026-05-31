import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo de la aplicación
            Center(
              child: Image.asset(
                'assets/verduras.png', // Asegúrate de tener un logo en esta ruta
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 16),

            // Título y versión
            const Text(
              'Fresc(o)rden',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Versión 1.3.3',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Descripción del propósito
            const Text(
              'Fresc(o)rden tiene como objetivo reducir la pérdida de alimentos en los hogares '
              'al incentivar a las personas a llevar un registro de sus productos y consumirlos '
              'en recetas deliciosas y prácticas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Futuras características
            const Text(
              '¡Estamos trabajando en nuevas características que llegarán pronto! Estas incluirán '
              'recomendaciones personalizadas, integración con IA para sugerir recetas, y mucho más.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            // Mensaje de agradecimiento
            const Text(
              'Gracias por ser parte de Fresc(o)rden. Juntos podemos hacer un cambio positivo '
              'en la forma en que gestionamos nuestros alimentos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}