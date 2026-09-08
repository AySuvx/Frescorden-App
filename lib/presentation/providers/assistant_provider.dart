import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/i_assistant_repository.dart';
import '../utils/quota_service.dart';
import 'product_provider.dart';

class AssistantProvider extends ChangeNotifier {
  final IAssistantRepository _repository;
  final ProductProvider _productProvider;

  AssistantProvider(this._repository, this._productProvider) {
    _loadQuota();
  }

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  int _remainingQueries = QuotaService.dailyLimit;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get remainingQueries => _remainingQueries;
  bool get isLimitReached => _remainingQueries <= 0;
  Duration get timeUntilReset => _timeUntilReset;

  Future<void> _loadQuota() async {
    _remainingQueries = await QuotaService.instance.getRemaining();
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
    } catch (e) {
      _error = e.toString();
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
    _remainingQueries = await QuotaService.instance.recordSuccessfulQuery();
    if (isLimitReached) _startCountdown();
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

  void _tickCountdown() {
    final remaining = QuotaService.instance.nextResetAt().difference(
          DateTime.now(),
        );

    if (!remaining.isNegative && remaining > Duration.zero) {
      _timeUntilReset = remaining;
      notifyListeners();
      return;
    }

    // Medianoche: se acabó la espera.
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _timeUntilReset = Duration.zero;
    _remainingQueries = QuotaService.dailyLimit;
    notifyListeners();
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
