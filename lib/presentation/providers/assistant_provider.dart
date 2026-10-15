import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/ai_exceptions.dart';
import '../../data/datasources/global_ai_quota_firestore_datasource.dart';
import '../../data/repositories/global_ai_quota_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/i_assistant_repository.dart';
import '../../domain/repositories/i_assistant_usage_repository.dart';
import '../../domain/repositories/i_global_ai_quota_repository.dart';
import '../../domain/services/i_assistant_analytics_service.dart';
import '../../domain/services/i_quota_service.dart';
import '../utils/analytics_service.dart';
import '../utils/quota_service.dart';
import 'product_provider.dart';

class AssistantProvider extends ChangeNotifier {
  final IAssistantRepository _repository;
  final ProductProvider _productProvider;

  // Adopción del asistente (Panel Administrativo).
  // Opcional para no romper ningún uso/test existente que construya
  // AssistantProvider sin él (mismo criterio que ProductProvider).
  final IAssistantUsageRepository? _usageRepository;

  // Igual criterio que HouseholdProvider/RecipeProvider: resuelto solo al
  // primer uso real (late final), nunca en el constructor.
  final IQuotaService? _injectedQuotaService;
  final IAssistantAnalyticsService? _injectedAnalyticsService;
  late final IQuotaService _quota = _injectedQuotaService ?? QuotaService.instance;
  late final IAssistantAnalyticsService _analytics =
      _injectedAnalyticsService ?? AnalyticsService.instance;

  // Cuota compartida entre TODOS los dispositivos del piloto (ver
  // IGlobalAiQuotaRepository) — se consulta ADEMÁS de `_quota` (que es
  // solo por dispositivo), nunca en su lugar.
  final IGlobalAiQuotaRepository? _injectedGlobalQuota;
  late final IGlobalAiQuotaRepository _globalQuota =
      _injectedGlobalQuota ??
      GlobalAiQuotaRepositoryImpl(GlobalAiQuotaFirestoreDataSource());

  AssistantProvider(
    this._repository,
    this._productProvider, [
    this._usageRepository,
    this._injectedQuotaService,
    this._injectedAnalyticsService,
    this._injectedGlobalQuota,
  ]) {
    _loadQuota();
  }

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  int _remainingQueries = QuotaService.dailyLimit;
  int _globalRemainingQueries = GlobalAiQuotaRepositoryImpl.cap;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // El menor de los dos: lo que de verdad queda disponible, no solo lo
  // que permite el dispositivo — si la cuota global del piloto está más
  // ajustada, mostrar el número del dispositivo sería engañoso.
  int get remainingQueries =>
      _remainingQueries < _globalRemainingQueries
          ? _remainingQueries
          : _globalRemainingQueries;
  bool get isLimitReached =>
      _remainingQueries <= 0 || _globalRemainingQueries <= 0;
  Duration get timeUntilReset => _timeUntilReset;

  Future<void> _loadQuota() async {
    _remainingQueries = await _quota.getRemaining();
    _globalRemainingQueries = await _globalQuota.getRemaining();
    if (isLimitReached) _startCountdown();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading || isLimitReached) return;

    _messages.add(ChatMessage(role: ChatRole.user, text: prompt));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reply = await _repository.sendMessage(
        prompt: prompt,
        currentInventory: _productProvider.products,
      );
      _messages.add(ChatMessage(role: ChatRole.model, text: reply));
      // Se descuenta SOLO tras una respuesta real — un fallo de red cae
      // en el catch de abajo y nunca llega hasta acá.
      await _recordSuccessfulQuery();
    } on AiQuotaExceededException catch (e) {
      _error = e.message;
      _messages.add(ChatMessage(role: ChatRole.model, text: e.message));
    } catch (e) {
      _error = e.toString();
      debugPrint('AssistantProvider.sendMessage error: $e');
      _messages.add(
        const ChatMessage(
          role: ChatRole.model,
          text: 'Ocurrió un error al responder. Intenta de nuevo.',
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _recordSuccessfulQuery() async {
    _remainingQueries = await _quota.recordSuccessfulQuery();
    _globalRemainingQueries = await _globalQuota.recordSuccessfulQuery();
    if (isLimitReached) _startCountdown();
    unawaited(_analytics.logAssistantQuery());

    final householdId = _productProvider.activeHouseholdId;
    if (_usageRepository != null && householdId != null) {
      unawaited(
        _usageRepository.logQuery(householdId: householdId).catchError(
          (e) => debugPrint('AssistantProvider._recordSuccessfulQuery usage log error: $e'),
        ),
      );
    }
  }

  /// Arranca el temporizador de 1s que cuenta hasta la medianoche. Al
  /// llegar a cero, reactiva la cuota sola (sin reiniciar la app) y se
  /// cancela — no hace falta arrancarlo de nuevo hasta la próxima vez que
  /// la cuota se agote.
  void _startCountdown() {
    _countdownTimer?.cancel();
    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
  }

  /// El reinicio que realmente importa para el contador visible: el más
  /// tardío entre los dos límites que están actualmente en cero. La cuota
  /// por dispositivo resetea a medianoche LOCAL, la global a medianoche
  /// UTC — no son la misma hora, así que no basta con mirar una sola.
  DateTime _effectiveNextReset() {
    final resets = <DateTime>[
      if (_remainingQueries <= 0) _quota.nextResetAt(),
      if (_globalRemainingQueries <= 0) _globalQuota.nextResetAt(),
    ];
    if (resets.isEmpty) return DateTime.now();
    return resets.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  void _tickCountdown() {
    final remaining = _effectiveNextReset().difference(DateTime.now());

    if (!remaining.isNegative && remaining > Duration.zero) {
      _timeUntilReset = remaining;
      notifyListeners();
      return;
    }

    // Se acabó la espera: se vuelve a consultar ambas cuotas en vez de
    // asumir el valor máximo, porque la global es compartida y puede que
    // otro dispositivo ya haya usado parte del nuevo día.
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _timeUntilReset = Duration.zero;
    unawaited(_loadQuota());
  }

  void clearConversation() {
    _messages.clear();
    _error = null;
    _repository.resetConversation();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
