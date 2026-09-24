abstract final class ExpirationAlertPolicy {
  static const leadDays = 3;

  /// Días que faltan para el vencimiento cuando el producto ya está dentro de
  /// la ventana de aviso (el momento de la alerta programada ya pasó), o
  /// `null` si no aplica: sin fecha, aún fuera de la ventana o ya vencido.
  static int? daysLeftInsideWindow(DateTime? expirationDate, DateTime now) {
    if (expirationDate == null) return null;
    final notifyAt = expirationDate.subtract(const Duration(days: leadDays));
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
