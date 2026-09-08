// lib/presentation/providers/household_provider.dart
//
// Proveedor de estado para el hogar familiar (Household). Implementa
// ChangeNotifier (mismo patrón que AuthProvider/ProductProvider).
//
// Cadena de streams reactiva:
//   uid (authStateChanges, escuchado directo en el constructor)
//     ──► watchActiveHouseholdId(uid)
//       ──► activeHouseholdId ──► watchHousehold(activeHouseholdId)
//         ──► household (miembros, código de invitación, etc.)
//
// Nota de diseño: se suscribe directo al Stream<AppUser?> de autenticación
// (el mismo que usa el StreamBuilder de main.dart) en vez de depender de
// AuthProvider.notifyListeners() vía ChangeNotifierProxyProvider — este
// último NO se dispara en una restauración de sesión silenciosa al abrir
// la app (Firebase Auth resuelve la sesión sin pasar por ningún método de
// AuthProvider), lo que dejaría a HouseholdProvider con `_uid = null` para
// una sesión que en realidad ya está activa.
//
// Cuando createHousehold/joinHousehold escriben `activeHouseholdId` en
// Firestore, el primer stream lo recoge solo — no hace falta refrescar
// nada manualmente, es la misma idea de "tiempo real" que ProductProvider.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/household.dart';
import '../../domain/repositories/i_household_repository.dart';

class HouseholdProvider extends ChangeNotifier {
  final IHouseholdRepository _repository;

  StreamSubscription<AppUser?>? _authSub;

  HouseholdProvider(this._repository, Stream<AppUser?> authStateChanges) {
    _authSub = authStateChanges.listen((user) {
      _email = user?.email;
      setUid(user?.uid);
    });
  }

  String? _uid;

  /// Email del usuario autenticado actual (si lo tiene) — se guarda
  /// denormalizado en `Household.memberEmails` al crear/unirse a un hogar,
  /// para que la UI ("Mi Hogar") pueda mostrar quién es cada miembro sin
  /// necesitar leer el perfil ajeno de cada uno (las reglas de Firestore
  /// restringen `usuarios/{uid}` al propio dueño).
  String? _email;
  String? _activeHouseholdId;
  Household? _household;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<String?>? _activeIdSub;
  StreamSubscription<Household?>? _householdSub;

  /// `false` hasta que `watchActiveHouseholdId` emita su primer valor para
  /// el uid actual. Distingue "todavía no sabemos" de "ya sabemos que es
  /// null" — necesario para disparar el bootstrap solo una vez, en el
  /// primer null real, y no en cada re-emisión posterior del stream.
  bool _activeIdKnown = false;

  /// Evita dos bootstraps concurrentes si el stream emitiera más de un
  /// `null` antes de que el primero termine de crear el hogar personal.
  bool _bootstrapping = false;

  // ─── Getters públicos ──────────────────────────────────────────────────

  String? get activeHouseholdId => _activeHouseholdId;
  Household? get household => _household;
  bool get hasHousehold => _activeHouseholdId != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// uid del usuario actual — para que la UI distinga "tú" del resto de
  /// `household.members` sin depender de otro provider.
  String? get currentUid => _uid;

  // ─── Reacción a cambios de sesión ──────────────────────────────────────

  /// Reacciona a un cambio de usuario autenticado (login/logout/cambio de
  /// cuenta), emitido por `authStateChanges` (ver constructor). Reinicia
  /// toda la cadena de streams para el nuevo [uid]. Público también para
  /// tests que quieran simular el cambio sin pasar por un Stream real.
  void setUid(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    unawaited(_activeIdSub?.cancel());
    unawaited(_householdSub?.cancel());
    _activeIdSub = null;
    _householdSub = null;
    _activeHouseholdId = null;
    _household = null;
    _error = null;
    _activeIdKnown = false;

    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _activeIdSub = _repository.watchActiveHouseholdId(uid).listen(
      _onActiveHouseholdIdChanged,
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _onActiveHouseholdIdChanged(String? householdId) {
    final isFirstEvent = !_activeIdKnown;
    _activeIdKnown = true;

    if (!isFirstEvent && householdId == _activeHouseholdId) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _activeHouseholdId = householdId;
    unawaited(_householdSub?.cancel());
    _householdSub = null;
    _household = null;

    if (householdId == null) {
      _isLoading = false;
      notifyListeners();
      // Primera vez que confirmamos que este usuario no tiene hogar: le
      // creamos uno personal y migramos su inventario legacy (ver
      // FirestoreHouseholdDataSource.bootstrapPersonalHousehold). El
      // stream de watchActiveHouseholdId recogerá el id nuevo solo.
      if (isFirstEvent) _bootstrapIfNeeded();
      return;
    }

    _householdSub = _repository.watchHousehold(householdId).listen(
      (household) {
        _household = household;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _bootstrapIfNeeded() async {
    final uid = _uid;
    if (uid == null || _bootstrapping) return;
    _bootstrapping = true;
    try {
      await _repository.bootstrapPersonalHousehold(uid, email: _email);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _bootstrapping = false;
    }
  }

  // ─── Acciones ───────────────────────────────────────────────────────────

  Future<void> createHousehold(String name) async {
    final uid = _uid;
    if (uid == null) {
      throw const HouseholdException('Debes iniciar sesión para crear un hogar.');
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // El stream de watchActiveHouseholdId recoge el cambio solo; no hace
      // falta setear estado local aquí a mano.
      await _repository.createHousehold(
        name: name,
        creatorUid: uid,
        creatorEmail: _email,
      );
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow; // La pantalla decide qué mensaje mostrar
    }
  }

  Future<void> joinHousehold(String code) async {
    final uid = _uid;
    if (uid == null) {
      throw const HouseholdException('Debes iniciar sesión para unirte a un hogar.');
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.joinHouseholdByCode(code: code, uid: uid, email: _email);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Renueva el código de invitación del hogar activo. Cualquier miembro
  /// puede llamarlo (no solo el administrador).
  Future<String> generateNewInviteCode() async {
    final householdId = _activeHouseholdId;
    if (householdId == null) {
      throw const HouseholdException('No hay un hogar activo.');
    }
    try {
      return await _repository.generateNewInviteCode(householdId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    unawaited(_activeIdSub?.cancel());
    unawaited(_householdSub?.cancel());
    super.dispose();
  }
}
