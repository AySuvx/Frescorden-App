enum ActivityAction { creado, editado, consumido, eliminado, desperdiciado }

extension ActivityActionLabel on ActivityAction {
  String get label {
    switch (this) {
      case ActivityAction.creado:
        return 'Creado';
      case ActivityAction.editado:
        return 'Editado';
      case ActivityAction.consumido:
        return 'Consumido';
      case ActivityAction.eliminado:
        return 'Eliminado';
      case ActivityAction.desperdiciado:
        return 'Desperdiciado';
    }
  }
}

class ActivityLogEntry {
  final String productName;
  final ActivityAction action;
  final String? userEmail;
  final DateTime timestamp;

  const ActivityLogEntry({
    required this.productName,
    required this.action,
    this.userEmail,
    required this.timestamp,
  });
}
