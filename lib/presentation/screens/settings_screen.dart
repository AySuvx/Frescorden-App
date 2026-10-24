// El estado de notificaciones se guarda y carga con SharedPreferences bajo
// la clave 'notifications_enabled', leída en initState de forma asíncrona.

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/theme_provider.dart';
import '../../domain/utils/expiration_alert_policy.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/product_provider.dart';
import '../utils/notification_service.dart';
import '../widgets/common/glass_dialog.dart';
import '../../routes.dart';
import 'login_screen.dart';

/// applicationId fijo del proyecto (ver android/app/build.gradle.kts) —
/// se necesita como String literal para el intent de ajustes de la app;
/// no hay una fuente en tiempo de ejecución más simple que agregar
/// package_info_plus solo para esto.
const _kPackageName = 'com.frescorden.app';

/// Fabricantes conocidos por tener ROMs con gestión de batería agresiva
/// que puede matar procesos en segundo plano antes de mostrar una
/// notificación programada (confirmado en prueba real: MIUI bloqueaba la
/// notificación pese a que la alarma sí se disparaba — ver commit del
/// hallazgo). La tarjeta de ayuda solo se muestra en estos fabricantes;
/// en un Pixel/AOSP estándar no aporta nada y solo generaría confusión.
const _kAggressiveRomManufacturers = {
  'xiaomi', 'redmi', 'poco', // MIUI / HyperOS
  'samsung', // One UI
  'huawei', 'honor', // EMUI / MagicOS
  'oppo', 'realme', 'oneplus', // ColorOS
  'vivo', 'iqoo', // OriginOS / FuntouchOS
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Español';

  /// `true` cuando el fabricante del dispositivo es conocido por matar
  /// procesos en segundo plano (ver _kAggressiveRomManufacturers). Controla
  /// si se muestra la tarjeta de ayuda de autoinicio/batería.
  bool _showBackgroundAlertsCard = false;

  // Clave SharedPreferences para persistir el estado de notificaciones
  static const _kNotifEnabled = 'notifications_enabled';

  // Ocultamiento Persistente de Alerta MIUI: una vez
  // que el usuario tocó "Configurar" o "Entendido, ocultar" en la tarjeta,
  // no se le vuelve a mostrar en esta o futuras aperturas de la pantalla —
  // ni siquiera si el fabricante sigue calificando como ROM agresiva.
  static const _kMiuiOptimizationDismissed = 'miui_optimization_dismissed';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkAggressiveRom();
  }

  Future<void> _checkAggressiveRom() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kMiuiOptimizationDismissed) ?? false) return;

    final info = await DeviceInfoPlugin().androidInfo;
    final manufacturer = info.manufacturer.toLowerCase();
    if (!mounted) return;
    setState(() {
      _showBackgroundAlertsCard =
          _kAggressiveRomManufacturers.any(manufacturer.contains);
    });
  }

  /// Guarda la bandera de descarte permanente y oculta la tarjeta de una
  /// vez — se llama tanto desde "Entendido, ocultar" (acá mismo) como desde
  /// el flujo de "Configurar" (ver _showBackgroundAlertsDialog), ya que
  /// ambas acciones cuentan como que el usuario ya vio y atendió el aviso.
  Future<void> _dismissBackgroundAlertsCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMiuiOptimizationDismissed, true);
    if (!mounted) return;
    setState(() => _showBackgroundAlertsCard = false);
  }

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

  /// Diálogo informativo antes de mandar al usuario a configurar el
  /// sistema — explica POR QUÉ se necesita, en vez de abrir ajustes sin
  /// contexto.
  Future<void> _showBackgroundAlertsDialog() async {
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alertas en segundo plano'),
        content: const Text(
          'Para asegurar que las alertas de vencimiento suenen a tiempo, '
          'asegúrate de activar "Autoinicio" y seleccionar "Sin '
          'restricciones" en Ahorro de batería.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ir a Configuración'),
          ),
        ],
      ),
    );

    if (goToSettings == true) {
      await _optimizeBackgroundAlerts();
      await _dismissBackgroundAlertsCard();
    }
  }

  /// Encadena las dos acciones del sistema relevantes:
  ///  1. Exención de optimización de batería — Android sí expone un intent
  ///     dedicado (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) que
  ///     permission_handler envuelve como Permission.ignoreBatteryOptimizations.
  ///  2. Información de la app — MIUI y otras ROMs no exponen un intent
  ///     público y estable específicamente para "Autoinicio" (el nombre del
  ///     componente cambia entre versiones); la pantalla de Información de
  ///     la App sí es una API estable de Android desde donde el usuario
  ///     puede llegar a los permisos/autoinicio específicos del fabricante.
  Future<void> _optimizeBackgroundAlerts() async {
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    try {
      await const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_kPackageName',
      ).launch();
    } catch (e) {
      debugPrint('No se pudo abrir la información de la app: $e');
    }
  }

  /// Aplica el cambio de antelación y reprograma la SERIE de avisos de
  /// cada producto con vencimiento ya cargado en memoria — sin esto, el
  /// valor nuevo solo surtiría efecto en el próximo producto agregado o
  /// editado, dejando el inventario existente avisando con la antelación
  /// vieja hasta que alguien lo tocara.
  Future<void> _setLeadDays(int days) async {
    await context.read<NotificationSettingsProvider>().setLeadDays(days);
    if (!mounted) return;
    final productos = context.read<ProductProvider>().products;
    for (final producto in productos) {
      if (producto.expirationDate != null) {
        unawaited(NotificationService.instance.scheduleExpirationAlert(producto));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final leadDays = context.watch<NotificationSettingsProvider>().leadDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Tema — ThemeProvider ahora persiste un
          // ThemeMode completo (antes solo un booleano claro/oscuro), así
          // que el control pasa de un Switch de 2 estados a un selector de
          // 3.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Oscuro'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest),
                label: Text('Sistema'),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (selection) {
              HapticFeedback.lightImpact();
              context.read<ThemeProvider>().setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 16),
          const Text('Color de acento', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final preset in AppColors.accentPresets)
                _AccentColorDot(
                  name: preset.key,
                  color: preset.value,
                  selected: themeProvider.seedColor.toARGB32() ==
                      preset.value.toARGB32(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ThemeProvider>().setSeedColor(preset.value);
                  },
                ),
            ],
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Notificaciones'),
            subtitle: const Text('Recibe recordatorios y alertas'),
            value: _notificationsEnabled,
            onChanged: _setNotificationsEnabled,
          ),
          if (_showBackgroundAlertsCard)
            Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  color: colorScheme.errorContainer,
                  margin: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.battery_alert,
                          color: colorScheme.onErrorContainer,
                        ),
                        title: Text(
                          'Optimizar alertas en segundo plano',
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                        subtitle: Text(
                          'Tu fabricante puede bloquear las notificaciones si '
                          'no activas Autoinicio y desactivas el ahorro de '
                          'batería.',
                          style: TextStyle(
                            color: colorScheme.onErrorContainer.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _dismissBackgroundAlertsCard,
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onErrorContainer,
                            ),
                            child: const Text('Entendido, ocultar'),
                          ),
                          TextButton(
                            onPressed: _showBackgroundAlertsDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onErrorContainer,
                            ),
                            child: const Text('Configurar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
          ListTile(
            title: const Text('Avisarme con antelación'),
            subtitle: Text(
              leadDays == 1
                  ? '1 día antes de que venza'
                  : '$leadDays días antes de que venza',
            ),
          ),
          Slider(
            value: leadDays.toDouble(),
            min: ExpirationAlertPolicy.minLeadDays.toDouble(),
            max: ExpirationAlertPolicy.maxLeadDays.toDouble(),
            divisions:
                ExpirationAlertPolicy.maxLeadDays -
                ExpirationAlertPolicy.minLeadDays,
            label: '$leadDays',
            onChanged: (value) {
              HapticFeedback.selectionClick();
              _setLeadDays(value.round());
            },
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
    final colorScheme = Theme.of(context).colorScheme;
    final bool? confirmed = await showGlassDialog<bool>(
      context: context,
      title: 'Eliminar cuenta',
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
          child: Text('Eliminar', style: TextStyle(color: colorScheme.error)),
        ),
      ],
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
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
            settings: const RouteSettings(name: AppRoutes.login),
          ),
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

/// Círculo de color seleccionable del selector de acento — un check
/// superpuesto marca el elegido en vez de depender solo de un borde (más
/// fácil de notar de un vistazo entre 7 colores similares en tamaño).
class _AccentColorDot extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AccentColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

// Callback de alarma top-level requerido por android_alarm_manager_plus
@pragma('vm:entry-point')
void _notificacionCallback() {
  debugPrint('Revisión periódica de vencimientos ejecutada');
}
