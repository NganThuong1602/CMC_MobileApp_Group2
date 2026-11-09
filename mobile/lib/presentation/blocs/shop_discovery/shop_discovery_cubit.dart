import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/repositories/social_repository.dart';

class ShopDiscoveryState extends Equatable {
  final List<ShopEntity> nearbyShops;
  final List<ShopEntity> highlightedShops;
  final String searchQuery;
  final double? minRatingFilter;
  final double? maxDistanceKmFilter;
  final int unreadNotificationCount;
  final bool locationPermissionAsked;
  final bool locationGranted;
  final bool hasRealDeviceGps;
  final double userLat;
  final double userLng;
  final int locationUpdateRevision;
  final int filterResetRevision;
  final bool isLoading;

  const ShopDiscoveryState({
    this.nearbyShops = const [],
    this.highlightedShops = const [],
    this.searchQuery = '',
    this.minRatingFilter,
    this.maxDistanceKmFilter,
    this.unreadNotificationCount = 0,
    this.locationPermissionAsked = false,
    this.locationGranted = false,
    this.hasRealDeviceGps = false,
    this.userLat = AppConstants.defaultLat,
    this.userLng = AppConstants.defaultLng,
    this.locationUpdateRevision = 0,
    this.filterResetRevision = 0,
    this.isLoading = false,
  });

  bool get hasActiveFilter =>
      minRatingFilter != null || maxDistanceKmFilter != null;

  ShopDiscoveryState copyWith({
    List<ShopEntity>? nearbyShops,
    List<ShopEntity>? highlightedShops,
    String? searchQuery,
    double? minRatingFilter,
    bool clearRatingFilter = false,
    double? maxDistanceKmFilter,
    bool clearDistanceFilter = false,
    int? unreadNotificationCount,
    bool? locationPermissionAsked,
    bool? locationGranted,
    bool? hasRealDeviceGps,
    double? userLat,
    double? userLng,
    int? locationUpdateRevision,
    int? filterResetRevision,
    bool? isLoading,
  }) {
    return ShopDiscoveryState(
      nearbyShops: nearbyShops ?? this.nearbyShops,
      highlightedShops: highlightedShops ?? this.highlightedShops,
      searchQuery: searchQuery ?? this.searchQuery,
      minRatingFilter: clearRatingFilter
          ? null
          : (minRatingFilter ?? this.minRatingFilter),
      maxDistanceKmFilter: clearDistanceFilter
          ? null
          : (maxDistanceKmFilter ?? this.maxDistanceKmFilter),
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      locationPermissionAsked:
          locationPermissionAsked ?? this.locationPermissionAsked,
      locationGranted: locationGranted ?? this.locationGranted,
      hasRealDeviceGps: hasRealDeviceGps ?? this.hasRealDeviceGps,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      locationUpdateRevision:
          locationUpdateRevision ?? this.locationUpdateRevision,
      filterResetRevision: filterResetRevision ?? this.filterResetRevision,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        nearbyShops,
        highlightedShops,
        searchQuery,
        minRatingFilter,
        maxDistanceKmFilter,
        unreadNotificationCount,
        locationPermissionAsked,
        locationGranted,
        hasRealDeviceGps,
        userLat,
        userLng,
        locationUpdateRevision,
        filterResetRevision,
        isLoading,
      ];
}

class ShopDiscoveryCubit extends Cubit<ShopDiscoveryState> {
  final ShopRepository shopRepository;
  final SocialRepository socialRepository;
  final LocationService locationService;

  ShopDiscoveryCubit({
    required this.shopRepository,
    required this.socialRepository,
    required this.locationService,
  }) : super(const ShopDiscoveryState());

  Future<void> loadAll({String? userId}) async {
    emit(state.copyWith(isLoading: true));
    final nearbyRes = await shopRepository.getNearbyShops(
      userLat: state.userLat,
      userLng: state.userLng,
      searchQuery: state.searchQuery,
      minRating: state.minRatingFilter,
    );
    final highlightRes = await shopRepository.getHighlightedShops();

    int unread = state.unreadNotificationCount;
    if (userId != null) {
      final notifRes = await socialRepository.getUserNotifications(userId);
      if (notifRes.isSuccess) {
        unread = notifRes.data!.where((n) => !n.isRead).length;
      }
    }

    // Tính lại khoảng cách (km) chuẩn xác từ tọa độ GPS thực tế của thiết bị tới từng quán
    // và áp dụng bộ lọc Đánh giá + Khoảng cách (từ 0 km -> maxDistanceKmFilter)
    final rawNearby = nearbyRes.data ?? state.nearbyShops;
    final minRating = state.minRatingFilter;
    final maxDistance = state.maxDistanceKmFilter;

    final computedNearby = rawNearby
        .map((shop) {
          final km = locationService.distanceKm(
            userLat: state.userLat,
            userLng: state.userLng,
            shopLat: shop.latitude,
            shopLng: shop.longitude,
          );
          return shop.copyWith(distanceKm: km);
        })
        .where((shop) {
          if (minRating != null && shop.rating < minRating) {
            return false;
          }
          if (maxDistance != null &&
              (shop.distanceKm < 0 || shop.distanceKm > maxDistance)) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final rawHighlights = highlightRes.data ?? state.highlightedShops;
    final computedHighlights = rawHighlights.map((shop) {
      final km = locationService.distanceKm(
        userLat: state.userLat,
        userLng: state.userLng,
        shopLat: shop.latitude,
        shopLng: shop.longitude,
      );
      return shop.copyWith(distanceKm: km);
    }).toList();

    emit(
      state.copyWith(
        nearbyShops: computedNearby,
        highlightedShops: computedHighlights,
        unreadNotificationCount: unread,
        isLoading: false,
      ),
    );
  }

  /// Gọi popup xin quyền truy cập GPS thực tế của thiết bị (Geolocator)
  /// và cập nhật Kinh độ & Vĩ độ thật của người dùng cho cả Danh sách lẫn Bản đồ OSM.
  Future<bool> requestRealDeviceLocation({String? userId}) async {
    emit(state.copyWith(locationPermissionAsked: true));
    final result = await locationService.requestAndGetCurrentLocation();
    if (result != null && result.granted) {
      emit(
        state.copyWith(
          locationPermissionAsked: true,
          locationGranted: true,
          hasRealDeviceGps: true,
          userLat: result.latitude,
          userLng: result.longitude,
          locationUpdateRevision: state.locationUpdateRevision + 1,
        ),
      );
      await loadAll(userId: userId);
      return true;
    }

    emit(
      state.copyWith(
        locationPermissionAsked: true,
        locationGranted: false,
      ),
    );
    await loadAll(userId: userId);
    return false;
  }

  /// Cho phép cập nhật trực tiếp tọa độ vị trí hiện tại của người dùng trên bản đồ
  /// và tính lại khoảng cách thực tế tới tất cả các quán.
  Future<void> setCustomUserLocation({
    required double latitude,
    required double longitude,
    String? userId,
  }) async {
    emit(
      state.copyWith(
        locationPermissionAsked: true,
        locationGranted: true,
        hasRealDeviceGps: true,
        userLat: latitude,
        userLng: longitude,
        locationUpdateRevision: state.locationUpdateRevision + 1,
      ),
    );
    await loadAll(userId: userId);
  }

  Future<void> updateSearch(String query) async {
    emit(state.copyWith(searchQuery: query));
    await loadAll();
  }

  Future<void> setMinRatingFilter(double? rating) async {
    emit(
      state.copyWith(
        minRatingFilter: rating,
        clearRatingFilter: rating == null,
      ),
    );
    await loadAll();
  }

  /// Áp dụng đồng thời bộ lọc Đánh giá sao & Khoảng cách (0 -> maxDistanceKm) khi bấm nút "Tìm kiếm" trong bảng lọc.
  Future<void> applyFilters({
    required double? minRating,
    required double? maxDistanceKm,
    String? userId,
  }) async {
    emit(
      state.copyWith(
        minRatingFilter: minRating,
        clearRatingFilter: minRating == null,
        maxDistanceKmFilter: maxDistanceKm,
        clearDistanceFilter: maxDistanceKm == null,
      ),
    );
    await loadAll(userId: userId);
  }

  /// Xoá sạch lựa chọn lọc (Đánh giá & Khoảng cách) khi bấm nút "Xoá lọc".
  Future<void> clearFilters({String? userId}) async {
    emit(
      state.copyWith(
        clearRatingFilter: true,
        clearDistanceFilter: true,
      ),
    );
    await loadAll(userId: userId);
  }

  /// Tự động xoá toàn bộ từ khoá tìm kiếm & bộ lọc khi chuyển qua lại giữa Trang chủ và Bản đồ.
  Future<void> resetAllSearchAndFiltersOnTabSwitch({String? userId}) async {
    emit(
      state.copyWith(
        searchQuery: '',
        clearRatingFilter: true,
        clearDistanceFilter: true,
        filterResetRevision: state.filterResetRevision + 1,
      ),
    );
    await loadAll(userId: userId);
  }
}
