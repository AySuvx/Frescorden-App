import '../../domain/entities/food_category.dart';
import '../../domain/entities/preset_food.dart';
import '../../domain/repositories/i_preset_food_repository.dart';
import '../datasources/preset_food_local_datasource.dart';

class PresetFoodRepositoryImpl implements IPresetFoodRepository {
  final PresetFoodLocalDataSource _dataSource;

  PresetFoodRepositoryImpl(this._dataSource);

  @override
  Future<List<PresetFood>> getAll() => _dataSource.getAll();

  @override
  Future<List<PresetFood>> getByCategory(FoodCategory category) async {
    final all = await _dataSource.getAll();
    return all.where((f) => f.category == category).toList();
  }
}
