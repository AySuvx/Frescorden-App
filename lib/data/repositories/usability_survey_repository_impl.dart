import '../../domain/entities/usability_survey_response.dart';
import '../../domain/repositories/i_usability_survey_repository.dart';
import '../datasources/firestore_usability_survey_datasource.dart';
import '../models/usability_survey_model.dart';

class UsabilitySurveyRepositoryImpl implements IUsabilitySurveyRepository {
  final FirestoreUsabilitySurveyDataSource _dataSource;

  UsabilitySurveyRepositoryImpl(this._dataSource);

  @override
  Future<bool> hasSubmitted(String uid) => _dataSource.hasSubmitted(uid);

  @override
  Future<void> submit(UsabilitySurveyResponse response) {
    return _dataSource.submit(
      response.uid,
      UsabilitySurveyModel(
        uid: response.uid,
        susAnswers: response.susAnswers,
        npsScore: response.npsScore,
        submittedAt: response.submittedAt,
      ),
    );
  }

  @override
  Future<List<UsabilitySurveyResponse>> getAll() => _dataSource.getAll();
}
