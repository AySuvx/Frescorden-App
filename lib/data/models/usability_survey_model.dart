import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/usability_survey_response.dart';

class UsabilitySurveyModel extends UsabilitySurveyResponse {
  const UsabilitySurveyModel({
    required super.uid,
    required super.susAnswers,
    required super.npsScore,
    required super.submittedAt,
  });

  factory UsabilitySurveyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['submittedAt'];
    return UsabilitySurveyModel(
      uid: doc.id,
      susAnswers: List<int>.from(data['susAnswers'] as List? ?? const []),
      npsScore: (data['npsScore'] as num?)?.toInt() ?? 0,
      submittedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'susAnswers': susAnswers,
      'npsScore': npsScore,
      'submittedAt': FieldValue.serverTimestamp(),
    };
  }
}
