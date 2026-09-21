import 'dart:async';

import '../../entities/household.dart';
import '../../repositories/i_household_repository.dart';
import '../../services/i_household_analytics_service.dart';

class CreateHouseholdUseCase {
  final IHouseholdRepository _repository;
  final IHouseholdAnalyticsService _analyticsService;

  const CreateHouseholdUseCase(this._repository, this._analyticsService);

  Future<Household> call({
    required String name,
    required String creatorUid,
    String? creatorEmail,
  }) async {
    final household = await _repository.createHousehold(
      name: name,
      creatorUid: creatorUid,
      creatorEmail: creatorEmail,
    );
    unawaited(_analyticsService.logHouseholdCreated());
    return household;
  }
}
