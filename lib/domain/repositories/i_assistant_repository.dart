import '../entities/product.dart';

abstract interface class IAssistantRepository {
  Future<String> sendMessage({
    required String prompt,
    List<Product>? currentInventory,
  });

  void resetConversation();
}
