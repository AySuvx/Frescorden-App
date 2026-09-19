// Implementación de IAdminRepository. Delega el cálculo a
// FirestoreAdminDataSource — ver ese archivo para el detalle de cómo se
// obtiene cada métrica.

import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/i_admin_repository.dart';
import '../datasources/firestore_admin_datasource.dart';

class AdminRepositoryImpl implements IAdminRepository {
  final FirestoreAdminDataSource _dataSource;

  AdminRepositoryImpl(this._dataSource);

  @override
  Future<AdminStats> getGlobalStats() => _dataSource.getGlobalStats();
}
