// lib/presentation/utils/quota_service.dart
//
// Cuota diaria de consultas al Asistente Gemini: 5 por dispositivo, en
// shared_preferences. Nudge de producto (freemium), NO una protección real
// contra abuso — se resetea desinstalando la app o usando otro dispositivo.
// La protección real de cuota compartida vive del lado de Firebase AI
// Logic (rate limit por usuario configurado en la consola de Firebase).

import 'package:shared_preferences/shared_preferences.dart';

class QuotaService {
  QuotaService._();
  static final QuotaService instance = QuotaService._();

  static const dailyLimit = 20;

  static const _kCountKey = 'assistant_daily_query_count';
  static const _kDateKey = 'assistant_daily_query_date';

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<int> _usedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kDateKey);
    if (storedDate != _dateKey(DateTime.now())) return 0; // cambió el día
    return prefs.getInt(_kCountKey) ?? 0;
  }

  /// Consultas que quedan disponibles hoy (0 a [dailyLimit]).
  Future<int> getRemaining() async {
    final used = await _usedToday();
    return (dailyLimit - used).clamp(0, dailyLimit);
  }

  /// Registra una consulta ya respondida con éxito y devuelve las
  /// consultas restantes. Solo debe llamarse tras una respuesta real de
  /// Gemini — nunca en un fallo de red (ver AssistantProvider.sendMessage).
  Future<int> recordSuccessfulQuery() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final used = (await _usedToday()) + 1;
    await prefs.setString(_kDateKey, today);
    await prefs.setInt(_kCountKey, used);
    return (dailyLimit - used).clamp(0, dailyLimit);
  }

  /// Medianoche del día siguiente (hora local del dispositivo) — cuándo
  /// se reinicia la cuota.
  DateTime nextResetAt() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }
}
