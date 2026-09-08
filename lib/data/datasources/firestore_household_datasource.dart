// lib/data/datasources/firestore_household_datasource.dart
//
// Única clase que habla directamente con Cloud Firestore para operaciones
// de Household. Encapsula:
//  - La colección '/households'
//  - La colección '/inviteCodes' (lookup código → householdId — ver nota
//    de diseño abajo y en firestore.rules)
//  - El campo 'activeHouseholdId' del documento 'usuarios/{uid}' (mismo
//    nombre de colección de perfil que ya usan FirestoreProductDataSource
//    y FirestoreProductHistoryDataSource; no se crea una colección
//    'users' nueva, para no fragmentar los datos del usuario).
//
// Diseño de '/inviteCodes' (por qué no es un `where('inviteCode', ...)`
// sobre '/households'): las reglas de seguridad de Firestore no son
// filtros — una query `list` se deniega COMPLETA si no se puede garantizar
// que todo documento que pudiera matchear es visible para quien consulta.
// Como quien se une a un hogar TODAVÍA no es miembro, una regla de lectura
// restringida a `members` bloquearía la propia búsqueda del hogar por
// código. La solución estándar de Firestore es una colección de lookup
// aparte, indexada por el propio código como ID de documento: un `get`
// puntual (no una query) sí puede evaluarse por documento. Ver
// firestore.rules para el detalle completo de las reglas de ambas
// colecciones.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/i_household_repository.dart';
import '../../domain/utils/invite_code_generator.dart';
import '../models/household_model.dart';
import '../models/user_model.dart';

class FirestoreHouseholdDataSource {
  final FirebaseFirestore _db;

  FirestoreHouseholdDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _householdsCol =>
      _db.collection('households');

  CollectionReference<Map<String, dynamic>> get _inviteCodesCol =>
      _db.collection('inviteCodes');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('usuarios').doc(uid);

  // ─── Lectura en tiempo real ─────────────────────────────────────────────

  Stream<String?> watchActiveHouseholdId(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserModel.fromJson(data, uid: uid).activeHouseholdId;
    });
  }

  Stream<HouseholdModel?> watchHousehold(String householdId) {
    return _householdsCol.doc(householdId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return HouseholdModel.fromFirestore(snap);
    });
  }

  // ─── Código de invitación ───────────────────────────────────────────────

  Future<String> _generateUniqueCode() async {
    const maxAttempts = 5;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final code = InviteCodeGenerator.generate();
      final exists = (await _inviteCodesCol.doc(code).get()).exists;
      if (!exists) return code;
    }
    throw const HouseholdException(
      'No se pudo generar un código de invitación único. Intenta de nuevo.',
    );
  }

  /// Registra en '/inviteCodes' que [code] apunta al hogar [householdId].
  /// Debe llamarse DESPUÉS de que el documento Household ya exista con el
  /// autor como miembro (la regla de escritura de '/inviteCodes' verifica
  /// membresía leyendo el hogar referenciado).
  Future<void> _registerInviteCode(String code, String householdId) {
    return _inviteCodesCol.doc(code).set({'householdId': householdId});
  }

  Future<void> _setActiveHouseholdId(String uid, String householdId) {
    return _userDoc(uid).set(
      UserModel(uid: uid, activeHouseholdId: householdId).toJson(),
      SetOptions(merge: true),
    );
  }

  // ─── Crear / Unirse / Renovar código ────────────────────────────────────

  /// Crea un hogar nuevo, vincula a [creatorUid] como administrador y
  /// primer miembro, y actualiza su `activeHouseholdId`.
  Future<HouseholdModel> create({
    required String name,
    required String creatorUid,
    String? creatorEmail,
  }) async {
    final code = await _generateUniqueCode();
    final ref = _householdsCol.doc();
    final model = HouseholdModel(
      id: ref.id,
      name: name,
      createdBy: creatorUid,
      members: [creatorUid],
      memberEmails:
          creatorEmail == null ? const {} : {creatorUid: creatorEmail},
      inviteCode: code,
      codeExpiresAt: InviteCodeGenerator.newExpiryDate(),
      createdAt: DateTime.now(),
    );
    await ref.set(model.toJson());
    await _registerInviteCode(code, ref.id);
    await _setActiveHouseholdId(creatorUid, ref.id);
    return model;
  }

  /// Busca un hogar por [code] (vía '/inviteCodes'), verifica que el
  /// código siga siendo el vigente del hogar (pudo haber sido rotado) y
  /// que no haya expirado, añade [uid] a `members` (si no lo era ya) y
  /// actualiza su `activeHouseholdId`.
  Future<HouseholdModel> joinByCode({
    required String code,
    required String uid,
    String? email,
  }) async {
    final inviteDoc = await _inviteCodesCol.doc(code).get();
    final householdId = inviteDoc.data()?['householdId'] as String?;
    if (!inviteDoc.exists || householdId == null) {
      throw const HouseholdException('El código de invitación no existe.');
    }

    final householdSnap = await _householdsCol.doc(householdId).get();
    if (!householdSnap.exists) {
      throw const HouseholdException('El hogar ya no existe.');
    }
    final household = HouseholdModel.fromFirestore(householdSnap);

    // El lookup pudo quedar apuntando a un código ya rotado (no se borran
    // los documentos viejos de '/inviteCodes' — ver nota de diseño): se
    // valida contra el código VIGENTE del hogar, no solo contra la
    // existencia del lookup.
    if (household.inviteCode != code) {
      throw const HouseholdException('El código de invitación ya no es válido.');
    }
    if (household.isInviteCodeExpired) {
      throw const HouseholdException(
        'El código de invitación ya expiró. Pide uno nuevo.',
      );
    }

    if (!household.isMember(uid)) {
      await householdSnap.reference.update({
        'members': FieldValue.arrayUnion([uid]),
        if (email != null) 'memberEmails.$uid': email,
      });
    }
    await _setActiveHouseholdId(uid, householdId);

    // Se relee el documento para devolver el estado real ya persistido
    // (incluye el uid recién agregado a members).
    final updatedDoc = await householdSnap.reference.get();
    return HouseholdModel.fromFirestore(updatedDoc);
  }

  /// Genera y guarda un código de invitación nuevo (24h de validez) para
  /// el hogar [householdId]. Devuelve el código nuevo.
  Future<String> generateNewInviteCode(String householdId) async {
    final code = await _generateUniqueCode();
    final expiresAt = InviteCodeGenerator.newExpiryDate();
    await _householdsCol.doc(householdId).update({
      'inviteCode': code,
      'codeExpiresAt': Timestamp.fromDate(expiresAt),
    });
    await _registerInviteCode(code, householdId);
    return code;
  }

  // ─── Migración: hogar personal + copia de inventario legacy ────────────
  //
  // Antes del módulo de Household, cada usuario tenía su propio inventario
  // en 'usuarios/{uid}/productos'. Para que nadie pierda su inventario al
  // pasar a 'households/{id}/productos', el primer acceso sin
  // `activeHouseholdId` dispara este bootstrap: crea un hogar personal
  // (1 solo miembro, el propio usuario) y copia esos documentos tal cual
  // hacia el hogar nuevo. Los documentos originales NO se borran — quedan
  // como respaldo hasta que se confirme que la migración funcionó bien.

  Future<void> bootstrapPersonalHousehold(String uid, {String? email}) async {
    // El código de invitación se genera fuera de la transacción: Firestore
    // no permite queries (where) dentro de una transacción, solo lecturas
    // de documentos puntuales.
    final code = await _generateUniqueCode();
    final expiresAt = InviteCodeGenerator.newExpiryDate();
    final householdRef = _householdsCol.doc();
    final now = DateTime.now();

    // La transacción evita duplicar el hogar personal si dos dispositivos
    // del mismo usuario disparan el bootstrap casi al mismo tiempo: solo
    // el primero en llegar encuentra `activeHouseholdId` vacío y crea.
    final created = await _db.runTransaction<bool>((tx) async {
      final userSnap = await tx.get(_userDoc(uid));
      final existingId = userSnap.data()?['activeHouseholdId'] as String?;
      if (existingId != null) return false;

      final model = HouseholdModel(
        id: householdRef.id,
        name: 'Mi hogar',
        createdBy: uid,
        members: [uid],
        memberEmails: email == null ? const {} : {uid: email},
        inviteCode: code,
        codeExpiresAt: expiresAt,
        createdAt: now,
      );
      tx.set(householdRef, model.toJson());
      tx.set(
        _userDoc(uid),
        UserModel(uid: uid, activeHouseholdId: householdRef.id).toJson(),
        SetOptions(merge: true),
      );
      return true;
    });

    if (!created) return; // otro dispositivo ya lo hizo primero

    // Se registra el lookup DESPUÉS de que la transacción confirme que el
    // hogar ya existe con el usuario como miembro (la regla de
    // '/inviteCodes' lee ese estado).
    await _registerInviteCode(code, householdRef.id);

    final legacyProductsCol =
        _db.collection('usuarios').doc(uid).collection('productos');
    final legacySnap = await legacyProductsCol.get();
    if (legacySnap.docs.isEmpty) return;

    final newProductsCol = householdRef.collection('productos');
    // Firestore permite hasta 500 escrituras por batch; se trocea por si
    // el inventario legacy fuera inusualmente grande.
    const chunkSize = 450;
    for (var i = 0; i < legacySnap.docs.length; i += chunkSize) {
      final chunk = legacySnap.docs.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final doc in chunk) {
        // Mismo docId: preserva continuidad si algo más lo referenciara.
        batch.set(newProductsCol.doc(doc.id), doc.data());
      }
      await batch.commit();
    }
  }
}
