// test/support/fake_repositories.dart
//
// Dobles de prueba en memoria para los repositorios de dominio (I*Repository)
// que consumen ProductProvider/ShoppingProvider/RecipeProvider/HouseholdProvider.
// No tocan Firebase: permiten probar la lógica de negocio real de los
// providers de forma aislada y determinística (BDD Given/When/Then).

import 'dart:async';

import 'package:frescorden/domain/entities/activity_log_entry.dart';
import 'package:frescorden/domain/entities/admin_stats.dart';
import 'package:frescorden/domain/entities/analytics_summary.dart';
import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/domain/entities/budget_tier.dart';
import 'package:frescorden/domain/entities/household.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/domain/entities/product_history_entry.dart';
import 'package:frescorden/domain/entities/recipe.dart';
import 'package:frescorden/domain/entities/shopping_item.dart';
import 'package:frescorden/domain/repositories/i_activity_log_repository.dart';
import 'package:frescorden/domain/repositories/i_admin_repository.dart';
import 'package:frescorden/domain/repositories/i_analytics_repository.dart';
import 'package:frescorden/domain/repositories/i_assistant_repository.dart';
import 'package:frescorden/domain/repositories/i_assistant_usage_repository.dart';
import 'package:frescorden/domain/repositories/i_auth_repository.dart';
import 'package:frescorden/domain/repositories/i_household_repository.dart';
import 'package:frescorden/domain/repositories/i_product_history_repository.dart';
import 'package:frescorden/domain/repositories/i_product_repository.dart';
import 'package:frescorden/domain/repositories/i_recipe_repository.dart';
import 'package:frescorden/domain/repositories/i_shopping_repository.dart';
import 'package:frescorden/domain/services/i_assistant_analytics_service.dart';
import 'package:frescorden/domain/services/i_quota_service.dart';

/// Fake de [IProductRepository]: `watchProducts` es un stream controlable
/// a mano ([emit]) para simular snapshots sucesivos de Firestore.
///
/// [findByNameResult]/[findByBarcodeResult] configuran de antemano lo que
/// devuelve la búsqueda de duplicados (por defecto `null`, "no existe").
/// Los `*Error` inyectan una falla del repositorio (p. ej. red/permisos)
/// para los escenarios "repositorio genera error" del formato BDD.
class FakeProductRepository implements IProductRepository {
  final _controllers = <String, StreamController<List<Product>>>{};
  final List<Product> added = [];
  final List<Product> updated = [];
  final List<String> deletedIds = [];

  Product? findByNameResult;
  Product? findByBarcodeResult;
  Object? addProductError;
  Object? updateProductError;
  Object? deleteProductError;

  StreamController<List<Product>> _controllerFor(String householdId) =>
      _controllers.putIfAbsent(
        householdId,
        () => StreamController<List<Product>>.broadcast(),
      );

  /// Simula un snapshot nuevo del stream de productos para [householdId].
  void emit(String householdId, List<Product> products) {
    _controllerFor(householdId).add(products);
  }

  /// Simula un error del stream (p. ej. pérdida de conexión).
  void emitError(String householdId, Object error) {
    _controllerFor(householdId).addError(error);
  }

  @override
  Stream<List<Product>> watchProducts(String householdId) =>
      _controllerFor(householdId).stream;

  @override
  Future<Product> addProduct(String householdId, Product product) async {
    if (addProductError != null) throw addProductError!;
    added.add(product);
    return product;
  }

  @override
  Future<void> updateProduct(String householdId, Product product) async {
    if (updateProductError != null) throw updateProductError!;
    updated.add(product);
  }

  @override
  Future<void> deleteProduct(String householdId, String id) async {
    if (deleteProductError != null) throw deleteProductError!;
    deletedIds.add(id);
  }

  @override
  Future<Product?> findByBarcode(String householdId, String barcode) async =>
      findByBarcodeResult;

  @override
  Future<Product?> findByName(String householdId, String name) async =>
      findByNameResult;

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}

/// Fake de [IShoppingRepository]: la canasta devuelta por [getBasket] se
/// configura por adelantado con [basketsByTier].
class FakeShoppingRepository implements IShoppingRepository {
  FakeShoppingRepository(this.basketsByTier);

  final Map<BudgetTier, List<ShoppingItem>> basketsByTier;
  Object? error;

  @override
  Future<List<ShoppingItem>> getBasket(BudgetTier tier) async {
    if (error != null) throw error!;
    return basketsByTier[tier] ?? [];
  }
}

/// Fake de [IRecipeRepository]: el catálogo devuelto por [getRecipes] se
/// configura por adelantado; [generateAiRecipe] es controlable con
/// [aiRecipeToReturn]/[aiRecipeError] para simular éxito o fallo del
/// fallback de IA.
class FakeRecipeRepository implements IRecipeRepository {
  FakeRecipeRepository(this.catalog);

  final List<Recipe> catalog;
  Recipe? aiRecipeToReturn;
  Object? aiRecipeError;
  Object? getRecipesError;

  /// Si se configura, [generateAiRecipe] espera este future en vez de
  /// resolver de inmediato — permite controlar el momento exacto en que
  /// la llamada termina para probar el guard de concurrencia.
  Future<Recipe>? aiRecipeFuture;

  @override
  Future<List<Recipe>> getRecipes() async {
    if (getRecipesError != null) throw getRecipesError!;
    return catalog;
  }

  @override
  Future<Recipe> generateAiRecipe(List<Product> inventory) async {
    if (aiRecipeFuture != null) return aiRecipeFuture!;
    if (aiRecipeError != null) throw aiRecipeError!;
    return aiRecipeToReturn ??
        (throw StateError('FakeRecipeRepository: configura aiRecipeToReturn'));
  }
}

/// Fake de [IQuotaService]: [remaining] configura cuántas consultas quedan
/// (default 5); [recordSuccessfulQuery] la decrementa y queda en
/// [recordedQueries] cuántas veces se llamó.
class FakeQuotaService implements IQuotaService {
  int remaining = 5;
  int recordedQueries = 0;

  @override
  Future<int> getRemaining() async => remaining;

  @override
  Future<int> recordSuccessfulQuery() async {
    recordedQueries++;
    remaining = remaining > 0 ? remaining - 1 : 0;
    return remaining;
  }

  /// Siempre relativo a "ahora": una fecha fija quedaría en el pasado con
  /// el tiempo, y AssistantProvider._tickCountdown() reinicia la cuota a
  /// dailyLimit en cuanto detecta que la medianoche configurada ya pasó.
  @override
  DateTime nextResetAt() => DateTime.now().add(const Duration(days: 1));
}

/// Fake de [IHouseholdRepository]: `watchActiveHouseholdId`/`watchHousehold`
/// son streams controlables a mano ([emitActiveId]/[emitHousehold]) para
/// simular la cadena reactiva real de HouseholdProvider. Las acciones
/// (removeMember, clearActiveHousehold, etc.) solo registran haber sido
/// llamadas — HouseholdProvider ya valida los permisos antes de invocarlas.
class FakeHouseholdRepository implements IHouseholdRepository {
  final _activeIdController = StreamController<String?>.broadcast();
  final _householdController = StreamController<Household?>.broadcast();

  final List<String> removedMemberUids = [];
  final List<String> clearedActiveHouseholdUids = [];
  final List<String> recordedActivityUids = [];
  final List<String> bootstrappedUids = [];
  Object? removeMemberError;
  Object? bootstrapError;
  Object? generateInviteCodeError;
  String inviteCodeToReturn = 'ABC123';

  /// Configurables para CreateHouseholdUseCase/JoinHouseholdUseCase: por
  /// defecto lanzan `UnimplementedError` (no usados en los escenarios de
  /// HouseholdProvider), a menos que el test fije un resultado o error.
  Household? createHouseholdResult;
  Object? createHouseholdError;
  Household? joinHouseholdResult;
  Object? joinHouseholdError;

  void emitActiveId(String? householdId) => _activeIdController.add(householdId);
  void emitHousehold(Household? household) => _householdController.add(household);
  void emitActiveIdError(Object error) => _activeIdController.addError(error);
  void emitHouseholdError(Object error) => _householdController.addError(error);

  @override
  Stream<String?> watchActiveHouseholdId(String uid) => _activeIdController.stream;

  @override
  Stream<Household?> watchHousehold(String householdId) => _householdController.stream;

  @override
  Future<Household> createHousehold({
    required String name,
    required String creatorUid,
    String? creatorEmail,
  }) async {
    if (createHouseholdError != null) throw createHouseholdError!;
    return createHouseholdResult ??
        (throw UnimplementedError('Configura createHouseholdResult.'));
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String code,
    required String uid,
    String? email,
  }) async {
    if (joinHouseholdError != null) throw joinHouseholdError!;
    return joinHouseholdResult ??
        (throw UnimplementedError('Configura joinHouseholdResult.'));
  }

  @override
  Future<String> generateNewInviteCode(String householdId) async {
    if (generateInviteCodeError != null) throw generateInviteCodeError!;
    return inviteCodeToReturn;
  }

  @override
  Future<void> bootstrapPersonalHousehold(String uid, {String? email}) async {
    bootstrappedUids.add(uid);
    if (bootstrapError != null) throw bootstrapError!;
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUid,
  }) async {
    if (removeMemberError != null) throw removeMemberError!;
    removedMemberUids.add(memberUid);
  }

  @override
  Future<void> clearActiveHousehold(String uid) async {
    clearedActiveHouseholdUids.add(uid);
  }

  @override
  Future<void> recordUserActivity(String uid) async {
    recordedActivityUids.add(uid);
  }

  void dispose() {
    unawaited(_activeIdController.close());
    unawaited(_householdController.close());
  }
}

/// Fake de [IProductHistoryRepository]: registra las entradas recibidas en
/// [logged]. [logResolutionError] simula una falla best-effort (el caller
/// -[ProductResolutionUseCase]- debe atraparla y no propagarla).
class FakeProductHistoryRepository implements IProductHistoryRepository {
  final List<ProductHistoryEntry> logged = [];
  Object? logResolutionError;

  @override
  Future<void> logResolution(
    String householdId,
    ProductHistoryEntry entry,
  ) async {
    if (logResolutionError != null) throw logResolutionError!;
    logged.add(entry);
  }
}

/// Fake de [IActivityLogRepository]: registra las llamadas a [logActivity]
/// en [logged]. [logActivityError] simula una falla best-effort.
class FakeActivityLogRepository implements IActivityLogRepository {
  final List<ActivityAction> logged = [];
  Object? logActivityError;

  @override
  Future<void> logActivity({
    required String householdId,
    required String productName,
    required ActivityAction action,
  }) async {
    if (logActivityError != null) throw logActivityError!;
    logged.add(action);
  }

  @override
  Stream<List<ActivityLogEntry>> watchRecentActivity(
    String householdId, {
    int limit = 20,
  }) => const Stream.empty();
}

/// Fake de [IAdminRepository]: [statsToReturn] configura el resultado de
/// [getGlobalStats]; [error] simula un fallo (p. ej. permisos, ya que las
/// reglas de Firestore restringen esta consulta al UID admin).
class FakeAdminRepository implements IAdminRepository {
  AdminStats statsToReturn = AdminStats.empty();
  Object? error;

  @override
  Future<AdminStats> getGlobalStats() async {
    if (error != null) throw error!;
    return statsToReturn;
  }
}

/// Fake de [IAnalyticsRepository]: [summaryToReturn] configura el
/// resultado de [getSummary]; [error] simula un fallo del repositorio.
class FakeAnalyticsRepository implements IAnalyticsRepository {
  AnalyticsSummary summaryToReturn = AnalyticsSummary.empty();
  Object? error;

  @override
  Future<AnalyticsSummary> getSummary(String householdId) async {
    if (error != null) throw error!;
    return summaryToReturn;
  }
}

/// Fake de [IAuthRepository]: cada método `*Error` inyecta la excepción a
/// lanzar (típicamente una subclase de `DomainException`); sin error,
/// registra la llamada en `calls` y no hace nada más. `currentUser`/
/// `authStateChanges` no se usan en los tests de LoginScreen (esa pantalla
/// no los consulta) pero completan la interfaz.
class FakeAuthRepository implements IAuthRepository {
  final List<String> calls = [];

  Object? signInError;
  Object? registerError;
  Object? signInWithGoogleError;
  Object? sendPasswordResetError;

  @override
  AppUser? currentUser;

  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signInWithEmail(String email, String password) async {
    calls.add('signInWithEmail');
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    calls.add('registerWithEmail');
    if (registerError != null) throw registerError!;
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    if (signInWithGoogleError != null) throw signInWithGoogleError!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('sendPasswordReset');
    if (sendPasswordResetError != null) throw sendPasswordResetError!;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
  }
}

/// Fake de [IAssistantRepository]: [replyToReturn] configura la respuesta
/// del modelo; [sendMessageError] simula un fallo de red/Gemini.
class FakeAssistantRepository implements IAssistantRepository {
  String replyToReturn = 'Respuesta de prueba';
  Object? sendMessageError;
  bool resetConversationCalled = false;
  final List<String> promptsSent = [];

  @override
  Future<String> sendMessage({
    required String prompt,
    List<Product>? currentInventory,
  }) async {
    promptsSent.add(prompt);
    if (sendMessageError != null) throw sendMessageError!;
    return replyToReturn;
  }

  @override
  void resetConversation() {
    resetConversationCalled = true;
  }
}

/// Fake de [IAssistantUsageRepository]: registra los `householdId` en
/// [loggedHouseholdIds]; [logQueryError] simula un fallo del registro
/// server-side (best-effort, no debe romper el flujo del asistente).
class FakeAssistantUsageRepository implements IAssistantUsageRepository {
  final List<String> loggedHouseholdIds = [];
  Object? logQueryError;

  @override
  Future<void> logQuery({required String householdId}) async {
    if (logQueryError != null) throw logQueryError!;
    loggedHouseholdIds.add(householdId);
  }
}

/// Fake de [IAssistantAnalyticsService]: cuenta cuántas veces se registró
/// una consulta exitosa del asistente.
class FakeAssistantAnalyticsService implements IAssistantAnalyticsService {
  int loggedQueries = 0;

  @override
  Future<void> logAssistantQuery() async {
    loggedQueries++;
  }
}
