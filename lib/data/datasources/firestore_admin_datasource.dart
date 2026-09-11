// lib/data/datasources/firestore_admin_datasource.dart
//
// Única clase que habla directamente con Cloud Firestore para el Panel
// Administrativo Global. Todas las consultas de acá requieren el UID admin
// (ver firestore.rules) — un usuario normal recibe un error de permisos.
//
// Cuatro lecturas, cada una necesaria por lo que expone:
//  - `usuarios`: se lee completa (no solo count()) porque ahora también
//    calculamos altas/activos recientes a partir de `createdAt`/
//    `lastActiveAt`. Esos son los únicos campos que ese documento guarda
//    (ver UserModel) — no hay contenido personal que este cambio exponga.
//  - `households`: igual que antes, completa para sumar `members`.
//  - collectionGroup('product_history'): historial de TODOS los hogares,
//    para el aprovechamiento global (Módulo 3).
//  - collectionGroup('assistant_usage'): adopción del asistente culinario.
//
// Ambos collectionGroup se leen sin filtro de fecha (Firestore exige un
// índice compuesto explícito para filtrar por rango en una collectionGroup
// query) y se acotan a los últimos N días en memoria — aceptable a la
// escala actual de la app; si el volumen crece, esto debería migrar a un
// rollup agregado (p. ej. una Cloud Function programada) en vez de leer
// todo el historial en cada apertura del panel.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/entities/product_history_entry.dart';
import '../models/product_history_model.dart';

class FirestoreAdminDataSource {
  final FirebaseFirestore _db;

  FirestoreAdminDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<AdminStats> getGlobalStats() async {
    final now = DateTime.now();
    final cutoff7 = now.subtract(const Duration(days: 7));
    final cutoff30 = now.subtract(const Duration(days: 30));

    final usersSnap = await _db.collection('usuarios').get();
    final householdsSnap = await _db.collection('households').get();
    final historySnap =
        await _db.collectionGroup('product_history').get();
    final assistantSnap =
        await _db.collectionGroup('assistant_usage').get();

    final (wastePercentage, consumed, discarded) =
        _globalWasteReduction(historySnap, cutoff30);
    final (assistantQueries, assistantHouseholds) =
        _assistantAdoption(assistantSnap, cutoff30);

    return AdminStats(
      totalUsers: usersSnap.docs.length,
      newUsersLast7Days: _countUsersSince(usersSnap, 'createdAt', cutoff7),
      activeUsersLast7Days: _countUsersSince(usersSnap, 'lastActiveAt', cutoff7),
      activeUsersLast30Days: _countUsersSince(usersSnap, 'lastActiveAt', cutoff30),
      totalHouseholds: householdsSnap.docs.length,
      totalHouseholdMembers: _totalMembers(householdsSnap),
      householdsWithExpiredInviteCode: _expiredInviteCodes(householdsSnap, now),
      globalWasteReductionPercentageLast30Days: wastePercentage,
      globalConsumedLast30Days: consumed,
      globalDiscardedLast30Days: discarded,
      assistantQueriesLast30Days: assistantQueries,
      householdsUsingAssistantLast30Days: assistantHouseholds,
    );
  }

  int _countUsersSince(
    QuerySnapshot<Map<String, dynamic>> usersSnap,
    String field,
    DateTime cutoff,
  ) {
    return usersSnap.docs.where((doc) {
      final value = doc.data()[field];
      return value is Timestamp && value.toDate().isAfter(cutoff);
    }).length;
  }

  int _totalMembers(QuerySnapshot<Map<String, dynamic>> householdsSnap) {
    var total = 0;
    for (final doc in householdsSnap.docs) {
      final members = doc.data()['members'];
      if (members is List) total += members.length;
    }
    return total;
  }

  int _expiredInviteCodes(
    QuerySnapshot<Map<String, dynamic>> householdsSnap,
    DateTime now,
  ) {
    var expired = 0;
    for (final doc in householdsSnap.docs) {
      final expiresAt = doc.data()['codeExpiresAt'];
      if (expiresAt is Timestamp && now.isAfter(expiresAt.toDate())) {
        expired++;
      }
    }
    return expired;
  }

  /// (%, consumidos, desperdiciados) sobre TODOS los hogares, acotado a
  /// [cutoff]. `%` es `null` si no hubo historial en la ventana.
  (double?, int, int) _globalWasteReduction(
    QuerySnapshot<Map<String, dynamic>> historySnap,
    DateTime cutoff,
  ) {
    final recent = historySnap.docs
        .map(ProductHistoryModel.fromFirestore)
        .where((e) => e.resolvedAt.isAfter(cutoff));

    var consumed = 0;
    var discarded = 0;
    for (final entry in recent) {
      if (entry.outcome == ProductOutcome.expired) {
        discarded++;
      } else {
        consumed++;
      }
    }

    final total = consumed + discarded;
    final percentage = total == 0 ? null : consumed / total * 100;
    return (percentage, consumed, discarded);
  }

  /// (consultas, hogares distintos) que usaron el asistente dentro de
  /// [cutoff].
  (int, int) _assistantAdoption(
    QuerySnapshot<Map<String, dynamic>> assistantSnap,
    DateTime cutoff,
  ) {
    var queries = 0;
    final households = <String>{};
    for (final doc in assistantSnap.docs) {
      final ts = doc.data()['timestamp'];
      if (ts is! Timestamp || !ts.toDate().isAfter(cutoff)) continue;
      queries++;
      final householdRef = doc.reference.parent.parent;
      if (householdRef != null) households.add(householdRef.id);
    }
    return (queries, households.length);
  }
}
