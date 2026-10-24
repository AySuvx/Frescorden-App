class NotificationPermissionGate {
  NotificationPermissionGate({required this.isEnabled, required this.request});

  final Future<bool> Function() isEnabled;
  final Future<bool> Function() request;

  // Una sola solicitud por sesión: evita repetir el diálogo en cada alerta.
  bool _asked = false;

  Future<void> ensure() async {
    if (_asked) return;
    _asked = true;
    if (await isEnabled()) return;
    await request();
  }
}
