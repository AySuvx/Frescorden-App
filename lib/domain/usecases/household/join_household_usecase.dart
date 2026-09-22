import 'dart:async';

import '../../entities/household.dart';
import '../../repositories/i_household_repository.dart';
import '../../services/i_household_analytics_service.dart';

class JoinHouseholdUseCase {
  final IHouseholdRepository _repository;
  final IHouseholdAnalyticsService _analyticsService;

  const JoinHouseholdUseCase(this._repository, this._analyticsService);

  Future<Household> call({
    required String code,
    required String uid,
    String? email,
  }) async {
    final household = await _repository.joinHouseholdByCode(
      code: code,
      uid: uid,
      email: email,
    );
    unawaited(_analyticsService.logHouseholdJoined());
    return household;
  }
}
