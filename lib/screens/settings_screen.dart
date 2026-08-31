// lib/screens/settings_screen.dart
//
// BUG #5 CORREGIDO (original): el toggle de modo oscuro usaba setState local.
//   FIX original: ThemeProvider via Provider (ya estaba aplicado en el ZIP).
//
// BUG #8 CORREGIDO: notificationsEnabled se reiniciaba a true en cada apertura
//   de la pantalla porque era una variable local sin persistencia.
//   FIX: Se guarda y carga con SharedPreferences bajo la clave
//   'notifications_enabled'. El valor se lee en initState de forma asíncrona.

import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/providers/auth_provider.dart';
import '../theme_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // BUG #8 FIX: valor inicial neutro; se sobreescribe desde SharedPreferences
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Español';

  // Clave SharedPreferences para persistir el estado de notificaciones
  static const _kNotifEnabled = 'notifications_enabled';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // BUG #8 FIX: carga el valor guardado al abrir la pantalla
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final enabled = prefs.getBool(_kNotifEnabled) ?? true;
    setState(() => _notificationsEnabled = enabled);
    // Android 13+ requiere el permiso POST_NOTIFICATIONS en tiempo de
    // ejecución: si el usuario ya tenía notificaciones activadas (o es la
    // primera vez que abre esta pantalla), se solicita al entrar.
    if (enabled) {
      await _requestNotificationPermission();
    }
  }

  // BUG #8 FIX: guarda el valor cada vez que el usuario lo cambia
  Future<void> _setNotificationsEnabled(bool value) async {
    if (value) {
      await _requestNotificationPermission();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifEnabled, value);
    setState(() => _notificationsEnabled = value);

    if (value) {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 24),
        0,
        _notificacionCallback,
        wakeup: true,
      );
    } else {
      await AndroidAlarmManager.cancel(0);
    }
  }

  /// Solicita el permiso POST_NOTIFICATIONS (Android 13+). Si el usuario ya
  /// lo denegó permanentemente, permission_handler no vuelve a mostrar el
  /// diálogo nativo — en ese caso se explica por qué se necesita y se ofrece
  /// un atajo directo a los ajustes del sistema.
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return;

    final result = await Permission.notification.request();
    if (result.isGranted) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notificaciones desactivadas'),
        content: const Text(
          'Para avisarte cuando un producto está por vencer, Fresc(o)rden '
          'necesita permiso para mostrar notificaciones. Actívalo desde '
          'los ajustes del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ir a ajustes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Modo oscuro — BUG #5 fix original (ThemeProvider)
          SwitchListTile(
            title: const Text('Modo oscuro'),
            subtitle: const Text('Activa o desactiva el tema oscuro'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              context.read<ThemeProvider>().toggleTheme(value);
            },
          ),
          const Divider(),

          // Notificaciones — BUG #8 fix
          SwitchListTile(
            title: const Text('Notificaciones'),
            subtitle: const Text('Recibe recordatorios y alertas'),
            value: _notificationsEnabled,
            onChanged: _setNotificationsEnabled,
          ),
          const Divider(),

          ListTile(
            title: const Text('Idioma'),
            subtitle: Text('Idioma actual: $_selectedLanguage'),
            trailing: const Icon(Icons.language),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Selecciona un idioma'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Español'),
                          onTap: () {
                            setState(() => _selectedLanguage = 'Español');
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('Inglés'),
                          onTap: () {
                            setState(() => _selectedLanguage = 'Inglés');
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const Divider(),

          ListTile(
            title: const Text('Eliminar cuenta'),
            subtitle: const Text(
                'Elimina tu cuenta y datos permanentemente'),
            trailing:
                const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _showConfirmationDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar tu cuenta? '
            'Esta acción no se puede deshacer y todos tus datos serán eliminados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await context.read<AuthProvider>().deleteAccount();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar la cuenta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la cuenta. Intenta nuevamente.'),
          ),
        );
      }
    }
  }
}

// Callback de alarma top-level requerido por android_alarm_manager_plus
@pragma('vm:entry-point')
void _notificacionCallback() {
  debugPrint('Revisión periódica de vencimientos ejecutada');
}
