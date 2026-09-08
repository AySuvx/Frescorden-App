import '../../domain/entities/product.dart';
import '../../domain/repositories/i_assistant_repository.dart';
import '../datasources/gemini_assistant_data_source.dart';

class AssistantRepositoryImpl implements IAssistantRepository {
  final GeminiAssistantDataSource _dataSource;

  AssistantRepositoryImpl(this._dataSource);

  @override
  Future<String> sendMessage({
    required String prompt,
    List<Product>? currentInventory,
  }) {
    return _dataSource.sendMessage(
      prompt: prompt,
      currentInventory: currentInventory,
    );
  }

  @override
  void resetConversation() => _dataSource.resetConversation();
}
