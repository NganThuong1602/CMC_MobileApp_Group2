import '../../core/enums/app_enums.dart';
import '../../core/utils/result.dart';
import '../entities/barber_entity.dart';
import '../entities/finance_entities.dart';
import '../entities/payment_transaction_entity.dart';
import '../entities/service_entity.dart';
import '../entities/shop_entity.dart';

abstract class ShopRepository {
  Future<Result<List<ShopEntity>>> getNearbyShops({
    double? userLat,
    double? userLng,
    String? searchQuery,
    double? minRating,
  });

  Future<Result<List<ShopEntity>>> getHighlightedShops();

  Future<Result<ShopEntity>> getShopById(String shopId);

  Future<Result<ShopEntity?>> getShopByOwnerId(String ownerId);

  Future<Result<List<ServiceEntity>>> getShopServices(String shopId);

  Future<Result<List<BarberEntity>>> getShopBarbers(String shopId);

  Future<Result<PaymentTransactionEntity>> createRegisterShopPayment({
    required String userId,
    required String name,
    required String address,
    required String phone,
    required String description,
    required String openTime,
    required String closeTime,
    required double latitude,
    required double longitude,
    String? coverImageUrl,
  });

  Future<Result<PaymentTransactionEntity>> createHighlightPayment({
    required String userId,
    required String shopId,
    required HighlightPackageType packageType,
  });

  Future<Result<PaymentTransactionEntity>> simulateSePayWebhook(
    String paymentCode,
  );

  Future<Result<ShopEntity>> updateShopInfo({
    required String shopId,
    required String name,
    required String address,
    required String phone,
    required String description,
    required String openTime,
    required String closeTime,
    String? coverImageUrl,
    List<String>? galleryUrls,
  });

  Future<Result<ServiceEntity>> upsertService({
    required String shopId,
    String? serviceId,
    required String name,
    required int price,
    required int durationMinutes,
    String? imageUrl,
  });

  Future<Result<void>> deleteService({
    required String shopId,
    required String serviceId,
  });

  Future<Result<ShopRevenueSummary>> getShopRevenueAndPayroll(String shopId);

  Future<Result<List<ShopEntity>>> getAdminPendingShops();

  Future<Result<List<ShopEntity>>> getAdminActiveShops();

  Future<Result<ShopEntity>> approveShopByAdmin(String shopId);

  Future<Result<void>> deleteShopByAdmin(String shopId);
}

