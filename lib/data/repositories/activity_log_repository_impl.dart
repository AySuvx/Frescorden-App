import '../../domain/entities/activity_log_entry.dart';
import '../../domain/repositories/i_activity_log_repository.dart';
import '../datasources/firestore_activity_log_datasource.dart';

class ActivityLogRepositoryImpl implements IActivityLogRepository {
  final FirestoreActivityLogDataSource _dataSource;

  ActivityLogRepositoryImpl(this._dataSource);

  @override
  Future<void> logActivity({
    required String householdId,
    required String productName,
    required ActivityAction action,
  }) {
    return _dataSource.logActivity(
      householdId: householdId,
      productName: productName,
      action: action,
    );
  }

  @override
  Stream<List<ActivityLogEntry>> watchRecentActivity(
    String householdId, {
    int limit = 20,
  }) {
    return _dataSource.watchRecentActivity(householdId, limit: limit);
  }
}
