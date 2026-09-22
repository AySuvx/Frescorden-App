import '../../entities/household.dart';
import '../../repositories/i_household_repository.dart';

/// Cubre tanto "Expulsar a otro miembro" (admin) como "Salir del hogar"
/// (el propio miembro) — ambos casos delegan en IHouseholdRepository.removeMember,
/// solo cambian las reglas de autorización según si [requesterUid] y
/// [targetUid] coinciden.
class RemoveMemberUseCase {
  final IHouseholdRepository _repository;

  const RemoveMemberUseCase(this._repository);

  Future<void> call(
    Household household, {
    required String requesterUid,
    required String targetUid,
  }) async {
    final isSelfRemoval = requesterUid == targetUid;

    if (isSelfRemoval) {
      if (requesterUid == household.createdBy) {
        throw const HouseholdException(
          'El administrador no puede salir de su propio hogar.',
        );
      }
    } else {
      if (requesterUid != household.createdBy) {
        throw const HouseholdException(
          'Solo el administrador del hogar puede expulsar miembros.',
        );
      }
      if (targetUid == household.createdBy) {
        throw const HouseholdException(
          'El administrador no puede expulsarse a sí mismo.',
        );
      }
    }

    await _repository.removeMember(
      householdId: household.id,
      memberUid: targetUid,
    );
    if (isSelfRemoval) {
      await _repository.clearActiveHousehold(requesterUid);
    }
  }
}
