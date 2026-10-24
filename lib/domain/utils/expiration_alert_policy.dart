abstract final class ExpirationAlertPolicy {
  static const defaultLeadDays = 3;
  static const minLeadDays = 1;
  static const maxLeadDays = 7;

  /// Días de antelación configurables desde Ajustes (ver
  /// NotificationSettingsProvider) — mutable a propósito, a diferencia del
  /// resto de esta clase: todo el código que ya leía `leadDays` como si
  /// fuera fijo (NotificationService, los casos de uso de producto, el
  /// dashboard) sigue funcionando sin cambios, solo que ahora refleja la
  /// preferencia del usuario en vez de un valor fijo.
  static int leadDays = defaultLeadDays;

  /// Fija [leadDays], recortado al rango [minLeadDays]–[maxLeadDays].
  static void setLeadDays(int days) {
    leadDays = days.clamp(minLeadDays, maxLeadDays);
  }

  /// Días que faltan para el vencimiento cuando el producto ya está dentro de
  /// la ventana de aviso (el momento de la alerta programada ya pasó), o
  /// `null` si no aplica: sin fecha, aún fuera de la ventana o ya vencido.
  static int? daysLeftInsideWindow(DateTime? expirationDate, DateTime now) {
    if (expirationDate == null) return null;
    final notifyAt = expirationDate.subtract(Duration(days: leadDays));
    if (notifyAt.isAfter(now)) return null;

    final today = DateTime.utc(now.year, now.month, now.day);
    final expiry = DateTime.utc(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    final daysLeft = expiry.difference(today).inDays;
    return daysLeft < 0 ? null : daysLeft;
  }

  static String describe(int daysLeft) => switch (daysLeft) {
    0 => 'hoy',
    1 => 'mañana',
    _ => 'en $daysLeft días',
  };
}
