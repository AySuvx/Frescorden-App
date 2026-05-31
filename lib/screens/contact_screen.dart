import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  // Función para abrir un enlace de correo
void _launchEmail(BuildContext context, String email) async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: email,
  );
  try {
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'No se encontró un cliente de correo configurado.';
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contáctanos',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 16),

            // Correo de contacto
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('contacto@frescorden.com'),
              subtitle: const Text('Envíanos un correo para cualquier consulta.'),
              onTap: () {
                _launchEmail(context, 'brayans011@outlook.com');
              },
            ),
            const Divider(),

            // Correo para reportar bugs
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('bugs@frescorden.com'),
              subtitle: const Text('Reporta errores o problemas en la aplicación.'),
              onTap: () {
                _launchEmail(context, 'brayans011@outlook.com');
              },
            ),
          ],
        ),
      ),
    );
  }
}