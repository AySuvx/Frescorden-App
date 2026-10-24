// Traduce el contador crudo de Firestore (GlobalAiQuotaFirestoreDataSource)
// al contrato de dominio IGlobalAiQuotaRepository: "cuántas consultas
// quedan hoy", no "cuántas van".
//
// `cap` es una red de seguridad contra un bug que dispare llamadas sin
// control, NO el límite real del día a día — ese lo pone QuotaService (20
// por dispositivo/persona). Mientras el proyecto use Vertex AI + Blaze
// (crédito de prueba gratuita, cuota dinámica, ver GeminiAssistantDataSource),
// no hay un tope fijo de Google que proteger, así que este valor puede ser
// generoso. Si el proyecto alguna vez vuelve al backend Gemini Developer
// API en el plan Spark, hay que bajar esto de nuevo a algo como 15 para no
// pasarse de ese límite.

import '../../domain/repositories/i_global_ai_quota_repository.dart';
import '../datasources/global_ai_quota_firestore_datasource.dart';

class GlobalAiQuotaRepositoryImpl implements IGlobalAiQuotaRepository {
  final GlobalAiQuotaFirestoreDataSource _dataSource;

  GlobalAiQuotaRepositoryImpl(this._dataSource);

  static const cap = 300;

  String _todayId() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  @override
  Future<int> getRemaining() async {
    final count = await _dataSource.getCount(_todayId());
    return (cap - count).clamp(0, cap);
  }

  @override
  Future<int> recordSuccessfulQuery() async {
    final count = await _dataSource.incrementAndGetCount(_todayId());
    return (cap - count).clamp(0, cap);
  }

  @override
  DateTime nextResetAt() {
    final nowUtc = DateTime.now().toUtc();
    return DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1);
  }
}
