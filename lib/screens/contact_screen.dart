// lib/screens/contact_screen.dart
//
// LINT FIX use_build_context_synchronously:
// _launchEmail usaba ScaffoldMessenger.of(context) después de awaits
// (canLaunchUrl / launchUrl), lo que es inseguro porque el widget puede
// haberse desmontado durante la espera.
// FIX: se captura el messenger en una variable local ANTES del primer await.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchEmail(BuildContext context, String email) async {
    // Capturar el messenger ANTES de cualquier await (fix use_build_context_synchronously)
    final messenger = ScaffoldMessenger.of(context);

    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'No se encontró un cliente de correo configurado.';
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
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
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('contacto@frescorden.com'),
              subtitle:
                  const Text('Envíanos un correo para cualquier consulta.'),
              onTap: () =>
                  _launchEmail(context, 'brayans011@outlook.com'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('bugs@frescorden.com'),
              subtitle: const Text(
                  'Reporta errores o problemas en la aplicación.'),
              onTap: () =>
                  _launchEmail(context, 'brayans011@outlook.com'),
            ),
          ],
        ),
      ),
    );
  }
}
