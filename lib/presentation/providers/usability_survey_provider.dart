// Proveedor de estado para la encuesta de usabilidad (SUS + NPS). A
// diferencia de AnalyticsProvider/HouseholdProvider, no reacciona a un
// stream — es una acción puntual (responder una vez) más una consulta
// puntual (¿ya respondió?), así que no necesita suscripción reactiva.

import 'package:flutter/foundation.dart';
import '../../domain/entities/usability_survey_response.dart';
import '../../domain/repositories/i_usability_survey_repository.dart';

class UsabilitySurveyProvider extends ChangeNotifier {
  final IUsabilitySurveyRepository _repository;

  UsabilitySurveyProvider(this._repository);

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<bool> hasSubmitted(String uid) => _repository.hasSubmitted(uid);

  Future<bool> submit({
    required String uid,
    required List<int> susAnswers,
    required int npsScore,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.submit(
        UsabilitySurveyResponse(
          uid: uid,
          susAnswers: susAnswers,
          npsScore: npsScore,
          submittedAt: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('UsabilitySurveyProvider.submit error: $e');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
