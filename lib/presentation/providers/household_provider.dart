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
import '../../domain/services/i_household_analytics_service.dart';
import '../../domain/usecases/household/create_household_usecase.dart';
import '../../domain/usecases/household/join_household_usecase.dart';
import '../../domain/usecases/household/remove_member_usecase.dart';
import '../utils/analytics_service.dart';

class HouseholdProvider extends ChangeNotifier {
  final IHouseholdRepository _repository;

  // Igual criterio que ProductProvider: resuelto solo al primer uso real
  // (ver los `late final` de abajo), nunca en el constructor.
  final IHouseholdAnalyticsService? _injectedAnalyticsService;

  late final IHouseholdAnalyticsService _analytics =
      _injectedAnalyticsService ?? AnalyticsService.instance;

  late final CreateHouseholdUseCase _createHouseholdUseCase =
      CreateHouseholdUseCase(_repository, _analytics);
  late final JoinHouseholdUseCase _joinHouseholdUseCase = JoinHouseholdUseCase(
    _repository,
    _analytics,
  );
  late final RemoveMemberUseCase _removeMemberUseCase = RemoveMemberUseCase(
    _repository,
  );

  StreamSubscription<AppUser?>? _authSub;

  HouseholdProvider(
    this._repository,
    Stream<AppUser?> authStateChanges, [
    this._injectedAnalyticsService,
  ]) {
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

    // Actividad de usuario (Panel Administrativo Global): best-effort, no
    // bloquea ni condiciona el resto de la resolución de sesión.
    unawaited(_repository.recordUserActivity(uid));

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

        // Me expulsaron (dejé de estar en members, pero el hogar sigue
        // existiendo): autocorrijo limpiando mi propio activeHouseholdId.
        // watchActiveHouseholdId recoge el null y dispara el bootstrap de
        // un hogar personal nuevo, igual que un usuario sin hogar — sin
        // esto quedaría "atado" a un hogar cuyo inventario ya no puede
        // leer (las reglas de Firestore exigen ser miembro).
        final uid = _uid;
        if (uid != null && household != null && !household.isMember(uid)) {
          unawaited(_repository.clearActiveHousehold(uid));
        }
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
      unawaited(_analytics.logHouseholdCreated());
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
      await _createHouseholdUseCase(
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
      await _joinHouseholdUseCase(code: code, uid: uid, email: _email);
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

  /// Expulsa a [memberUid] del hogar activo — reglas de autorización en
  /// [RemoveMemberUseCase] (solo el administrador puede expulsar a otros;
  /// no puede expulsarse a sí mismo por esta vía, ver [leaveHousehold]).
  Future<void> removeMember(String memberUid) async {
    final household = _household;
    final uid = _uid;
    if (household == null || uid == null) {
      throw const HouseholdException('No hay un hogar activo.');
    }

    try {
      await _removeMemberUseCase(
        household,
        requesterUid: uid,
        targetUid: memberUid,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// El usuario actual sale del hogar activo — reglas de autorización en
  /// [RemoveMemberUseCase] (el administrador no puede salir por esta vía,
  /// debe expulsar a los demás miembros primero). El bootstrap (mismo
  /// mecanismo que un usuario nuevo sin hogar) le crea uno personal solo —
  /// ver _onActiveHouseholdIdChanged.
  Future<void> leaveHousehold() async {
    final household = _household;
    final uid = _uid;
    if (household == null || uid == null) {
      throw const HouseholdException('No hay un hogar activo.');
    }

    try {
      await _removeMemberUseCase(household, requesterUid: uid, targetUid: uid);
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
