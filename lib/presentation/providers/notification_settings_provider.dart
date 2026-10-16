// Persiste la preferencia de "con cuántos días de antelación avisar" bajo
// la clave 'notification_lead_days' en SharedPreferences (mismo patrón que
// ThemeProvider) y la refleja en ExpirationAlertPolicy.leadDays — el único
// lugar que el resto del código (NotificationService, los casos de uso de
// producto, el dashboard) ya consultaba como si fuera un valor fijo.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/utils/expiration_alert_policy.dart';

class NotificationSettingsProvider with ChangeNotifier {
  static const _prefsKey = 'notification_lead_days';

  int _leadDays = ExpirationAlertPolicy.defaultLeadDays;

  int get leadDays => _leadDays;

  NotificationSettingsProvider() {
    _loadLeadDays();
  }

  Future<void> setLeadDays(int days) async {
    final clamped = days.clamp(
      ExpirationAlertPolicy.minLeadDays,
      ExpirationAlertPolicy.maxLeadDays,
    );
    if (_leadDays == clamped) return;
    _leadDays = clamped;
    ExpirationAlertPolicy.setLeadDays(clamped);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, clamped);
  }

  Future<void> _loadLeadDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefsKey);
    if (stored == null) return;
    _leadDays = stored.clamp(
      ExpirationAlertPolicy.minLeadDays,
      ExpirationAlertPolicy.maxLeadDays,
    );
    ExpirationAlertPolicy.setLeadDays(_leadDays);
    notifyListeners();
  }
}
