import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' show Position;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/repositories/social_repository.dart';

class ShopDiscoveryState extends Equatable {
  final bool onlyHighlightedFilter;
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
  final double gpsAccuracyMeters;
  final int locationUpdateRevision;
  final int filterResetRevision;
  final bool isLoading;

  const ShopDiscoveryState({
    this.onlyHighlightedFilter = false,
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
    this.gpsAccuracyMeters = 0,
    this.locationUpdateRevision = 0,
    this.filterResetRevision = 0,
    this.isLoading = false,
  });

  /// Bộ lọc trong Bottom Sheet (Đánh giá & Khoảng cách).
  /// "Nổi bật" là tab chọn nhanh riêng ở Trang chủ nên KHÔNG tính là bộ lọc.
  bool get hasActiveFilter =>
      minRatingFilter != null || maxDistanceKmFilter != null;

  /// Chỉ hiển thị chấm xanh vị trí khi đã có toạ độ GPS thật và định vị đang bật.
  bool get showUserLocationDot => locationGranted && hasRealDeviceGps;

  ShopDiscoveryState copyWith({
    bool? onlyHighlightedFilter,
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
    double? gpsAccuracyMeters,
    int? locationUpdateRevision,
    int? filterResetRevision,
    bool? isLoading,
  }) {
    return ShopDiscoveryState(
      onlyHighlightedFilter:
          onlyHighlightedFilter ?? this.onlyHighlightedFilter,
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
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      locationUpdateRevision:
          locationUpdateRevision ?? this.locationUpdateRevision,
      filterResetRevision: filterResetRevision ?? this.filterResetRevision,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        onlyHighlightedFilter,
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
        gpsAccuracyMeters,
        locationUpdateRevision,
        filterResetRevision,
        isLoading,
      ];
}

class ShopDiscoveryCubit extends Cubit<ShopDiscoveryState> {
  final ShopRepository shopRepository;
  final SocialRepository socialRepository;
  final LocationService locationService;
  StreamSubscription<Position>? _locationSub;
  Timer? _availabilityTimer;
  bool _checkingAvailability = false;

  ShopDiscoveryCubit({
    required this.shopRepository,
    required this.socialRepository,
    required this.locationService,
  }) : super(const ShopDiscoveryState());

  /// Bắt đầu theo dõi GPS thật theo thời gian thực + giám sát trạng thái bật/tắt định vị.
  void startLiveLocationTracking() {
    _startAvailabilityWatcher();
    if (_locationSub != null) return;
    _locationSub = locationService.watchRawPosition().listen(
      (pos) => updateLiveCoordinates(
        pos.latitude,
        pos.longitude,
        accuracyMeters: pos.accuracy,
      ),
      onError: (_) => _markLocationUnavailable(),
      onDone: () => _locationSub = null,
      cancelOnError: true,
    );
  }

  void _stopLiveLocationStream() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  /// Định kỳ kiểm tra người dùng có tắt định vị / thu hồi quyền hay không.
  /// - Tắt: ẩn chấm xanh vị trí ngay lập tức.
  /// - Bật lại: tự động lấy lại GPS thật và hiện lại chấm xanh.
  void _startAvailabilityWatcher() {
    _availabilityTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkAvailability(),
    );
  }

  Future<void> _checkAvailability() async {
    if (_checkingAvailability || isClosed) return;
    _checkingAvailability = true;
    try {
      final available = await locationService.isLocationAvailable();
      if (isClosed) return;
      if (!available) {
        if (state.locationGranted || _locationSub != null) {
          _markLocationUnavailable();
        }
        return;
      }
      if (!state.showUserLocationDot || _locationSub == null) {
        final loc = await locationService.requestAndGetCurrentLocation();
        if (isClosed) return;
        if (loc != null && loc.granted) {
          updateLiveCoordinates(
            loc.latitude,
            loc.longitude,
            accuracyMeters: loc.accuracyMeters,
          );
        }
        startLiveLocationTracking();
      }
    } finally {
      _checkingAvailability = false;
    }
  }

  void _markLocationUnavailable() {
    _stopLiveLocationStream();
    if (isClosed) return;
    if (!state.locationGranted && !state.hasRealDeviceGps) return;
    emit(
      state.copyWith(
        locationGranted: false,
        hasRealDeviceGps: false,
      ),
    );
  }

  void updateLiveCoordinates(
    double lat,
    double lng, {
    double? accuracyMeters,
  }) {
    final now = DateTime.now();
    final updatedNearby = state.nearbyShops.map((shop) {
      final km = locationService.distanceKm(
        userLat: lat,
        userLng: lng,
        shopLat: shop.latitude,
        shopLng: shop.longitude,
      );
      return shop.copyWith(distanceKm: km);
    }).toList()
      ..sort((a, b) {
        final ha = a.isHighlightedAt(now) ? 1 : 0;
        final hb = b.isHighlightedAt(now) ? 1 : 0;
        if (ha != hb) return hb.compareTo(ha);
        return a.distanceKm.compareTo(b.distanceKm);
      });

    final updatedHighlights = state.highlightedShops.map((shop) {
      final km = locationService.distanceKm(
        userLat: lat,
        userLng: lng,
        shopLat: shop.latitude,
        shopLng: shop.longitude,
      );
      return shop.copyWith(distanceKm: km);
    }).toList();

    emit(
      state.copyWith(
        locationGranted: true,
        hasRealDeviceGps: true,
        userLat: lat,
        userLng: lng,
        gpsAccuracyMeters: accuracyMeters ?? state.gpsAccuracyMeters,
        nearbyShops: updatedNearby,
        highlightedShops: updatedHighlights,
        locationUpdateRevision: state.locationUpdateRevision + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    _availabilityTimer?.cancel();
    await _locationSub?.cancel();
    return super.close();
  }

  Future<void> loadAll({String? userId}) async {
    emit(state.copyWith(isLoading: true));
    final nearbyRes = await shopRepository.getNearbyShops(
      userLat: state.userLat,
      userLng: state.userLng,
      searchQuery: state.searchQuery,
      minRating: state.minRatingFilter,
      onlyHighlighted: state.onlyHighlightedFilter,
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
    // Ưu tiên quán Nổi bật (Hợp tác) lên đầu Trang chủ và áp dụng bộ lọc.
    final rawNearby = nearbyRes.data ?? state.nearbyShops;
    final minRating = state.minRatingFilter;
    final maxDistance = state.maxDistanceKmFilter;
    final now = DateTime.now();

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
          if (state.onlyHighlightedFilter && !shop.isHighlightedAt(now)) {
            return false;
          }
          if (minRating != null &&
              (shop.reviewCount <= 0 || shop.rating < minRating)) {
            return false;
          }
          if (maxDistance != null &&
              (shop.distanceKm < 0 || shop.distanceKm > maxDistance)) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        final ha = a.isHighlightedAt(now) ? 1 : 0;
        final hb = b.isHighlightedAt(now) ? 1 : 0;
        if (ha != hb) return hb.compareTo(ha);
        return a.distanceKm.compareTo(b.distanceKm);
      });

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
          gpsAccuracyMeters: result.accuracyMeters,
          locationUpdateRevision: state.locationUpdateRevision + 1,
        ),
      );
      startLiveLocationTracking();
      await loadAll(userId: userId);
      return true;
    }

    emit(
      state.copyWith(
        locationPermissionAsked: true,
        locationGranted: false,
        hasRealDeviceGps: false,
      ),
    );
    _startAvailabilityWatcher();
    await loadAll(userId: userId);
    return false;
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

  Future<void> toggleHighlightedFilter({String? userId}) async {
    emit(
      state.copyWith(
        onlyHighlightedFilter: !state.onlyHighlightedFilter,
      ),
    );
    await loadAll(userId: userId);
  }

  /// Áp dụng đồng thời bộ lọc Nổi bật, Đánh giá sao & Khoảng cách (0 -> maxDistanceKm) khi bấm "Tìm kiếm".
  Future<void> applyFilters({
    required double? minRating,
    required double? maxDistanceKm,
    bool? onlyHighlighted,
    String? userId,
  }) async {
    emit(
      state.copyWith(
        onlyHighlightedFilter: onlyHighlighted ?? state.onlyHighlightedFilter,
        minRatingFilter: minRating,
        clearRatingFilter: minRating == null,
        maxDistanceKmFilter: maxDistanceKm,
        clearDistanceFilter: maxDistanceKm == null,
      ),
    );
    await loadAll(userId: userId);
  }

  /// Xoá lựa chọn lọc (Đánh giá & Khoảng cách) khi bấm nút "Xoá lọc".
  /// Giữ nguyên tab "Tất cả" / "Nổi bật" mà người dùng đang chọn ở Trang chủ.
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
        onlyHighlightedFilter: false,
        clearRatingFilter: true,
        clearDistanceFilter: true,
        filterResetRevision: state.filterResetRevision + 1,
      ),
    );
    await loadAll(userId: userId);
  }
}
