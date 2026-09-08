import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/activity_log_entry.dart';

class ActivityLogModel extends ActivityLogEntry {
  const ActivityLogModel({
    required super.productName,
    required super.action,
    super.userEmail,
    required super.timestamp,
  });

  factory ActivityLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['timestamp'];
    return ActivityLogModel(
      productName: data['productName'] as String? ?? '',
      action: ActivityAction.values.firstWhere(
        (a) => a.name == data['action'],
        orElse: () => ActivityAction.editado,
      ),
      userEmail: data['userEmail'] as String?,
      // pendiente de resolver server-side justo tras escribir (offline):
      // se muestra "ahora" hasta que el snapshot real llegue.
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'productName': productName,
      'action': action.name,
      'userEmail': userEmail,
      if (userId != null) 'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
