// lib/data/repositories/assistant_usage_repository_impl.dart
//
// Implementación de IAssistantUsageRepository. Delega al DataSource.

import '../../domain/repositories/i_assistant_usage_repository.dart';
import '../datasources/firestore_assistant_usage_datasource.dart';

class AssistantUsageRepositoryImpl implements IAssistantUsageRepository {
  final FirestoreAssistantUsageDataSource _dataSource;

  AssistantUsageRepositoryImpl(this._dataSource);

  @override
  Future<void> logQuery({required String householdId}) {
    return _dataSource.logQuery(householdId);
  }
}
