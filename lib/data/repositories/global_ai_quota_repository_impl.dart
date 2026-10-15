// Traduce el contador crudo de Firestore (GlobalAiQuotaFirestoreDataSource)
// al contrato de dominio IGlobalAiQuotaRepository: "cuántas consultas
// quedan hoy", no "cuántas van". `cap` se queda deliberadamente por debajo
// del límite real de Google (20/día en el plan Spark, ver docs/API.docx)
// para dejar margen a solicitudes que no pasan por este contador
// (depuración directa desde la consola, pequeños desfases de red entre el
// incremento y la lectura de confirmación).

import '../../domain/repositories/i_global_ai_quota_repository.dart';
import '../datasources/global_ai_quota_firestore_datasource.dart';

class GlobalAiQuotaRepositoryImpl implements IGlobalAiQuotaRepository {
  final GlobalAiQuotaFirestoreDataSource _dataSource;

  GlobalAiQuotaRepositoryImpl(this._dataSource);

  static const cap = 15;

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
