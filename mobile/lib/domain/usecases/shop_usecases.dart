import '../../core/utils/result.dart';
import '../entities/shop_entity.dart';
import '../repositories/shop_repository.dart';

class GetNearbyShopsUseCase {
  final ShopRepository repository;
  const GetNearbyShopsUseCase(this.repository);

  Future<Result<List<ShopEntity>>> call({
    double? userLat,
    double? userLng,
    String? searchQuery,
    double? minRating,
  }) {
    return repository.getNearbyShops(
      userLat: userLat,
      userLng: userLng,
      searchQuery: searchQuery,
      minRating: minRating,
    );
  }
}

class GetHighlightedShopsUseCase {
  final ShopRepository repository;
  const GetHighlightedShopsUseCase(this.repository);

  Future<Result<List<ShopEntity>>> call() {
    return repository.getHighlightedShops();
  }
}

