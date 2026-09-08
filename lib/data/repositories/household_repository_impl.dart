// lib/data/repositories/household_repository_impl.dart
//
// Implementación concreta de IHouseholdRepository usando Firestore.
// Traduce entre la entidad de dominio (Household) y el modelo de datos
// (HouseholdModel), delegando todas las operaciones al DataSource.

import '../../domain/entities/household.dart';
import '../../domain/repositories/i_household_repository.dart';
import '../datasources/firestore_household_datasource.dart';

class HouseholdRepositoryImpl implements IHouseholdRepository {
  final FirestoreHouseholdDataSource _dataSource;

  HouseholdRepositoryImpl(this._dataSource);

  @override
  Stream<String?> watchActiveHouseholdId(String uid) {
    return _dataSource.watchActiveHouseholdId(uid);
  }

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return _dataSource.watchHousehold(householdId);
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String creatorUid,
    String? creatorEmail,
  }) {
    return _dataSource.create(
      name: name,
      creatorUid: creatorUid,
      creatorEmail: creatorEmail,
    );
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String code,
    required String uid,
    String? email,
  }) {
    return _dataSource.joinByCode(code: code, uid: uid, email: email);
  }

  @override
  Future<String> generateNewInviteCode(String householdId) {
    return _dataSource.generateNewInviteCode(householdId);
  }

  @override
  Future<void> bootstrapPersonalHousehold(String uid, {String? email}) {
    return _dataSource.bootstrapPersonalHousehold(uid, email: email);
  }
}
