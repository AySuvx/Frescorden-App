import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/i_assistant_repository.dart';
import 'product_provider.dart';

class AssistantProvider extends ChangeNotifier {
  final IAssistantRepository _repository;
  final ProductProvider _productProvider;

  AssistantProvider(this._repository, this._productProvider);

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;

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

  void clearConversation() {
    _messages.clear();
    _error = null;
    _repository.resetConversation();
    notifyListeners();
  }
}
