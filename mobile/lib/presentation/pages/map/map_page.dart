import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../../widgets/shop_filter_bottom_sheet.dart';
import '../shop/shop_detail_bottom_sheet.dart';

/// Màn hình Bản đồ chuẩn Pixel-perfect theo Ảnh 5:
/// - Dùng `flutter_map` kết hợp dữ liệu OpenStreetMap (OSM) (KHÔNG dùng Google Maps).
/// - Lấy tọa độ GPS thật từ thiết bị qua `geolocator` và đặt tâm bản đồ tại đúng vị trí hiện tại của user.
/// - Các Marker màu xanh lá `#00A859` hình Cái kéo + nhãn trắng hiển thị Tên quán & Khoảng cách thực tế (`km`).
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _mapSearchCtrl = TextEditingController();
  bool _isMapReady = false;

  @override
  void dispose() {
    _mapSearchCtrl.dispose();
    super.dispose();
  }

  void _safeMoveMap(double lat, double lng, {double zoom = 14.8}) {
    if (!_isMapReady || !mounted) return;
    _mapController.move(LatLng(lat, lng), zoom);
  }

  Future<void> _recenterToRealGps() async {
    final userId = context.read<AuthCubit>().state.user?.id;
    final cubit = context.read<ShopDiscoveryCubit>();
    final granted = await cubit.requestRealDeviceLocation(userId: userId);
    if (!mounted) return;
    final updated = cubit.state;
    _safeMoveMap(updated.userLat, updated.userLng, zoom: 15.2);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa cấp quyền GPS thiết bị — đang hiển thị khu vực Vạn Phúc, Hà Đông.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    return BlocConsumer<ShopDiscoveryCubit, ShopDiscoveryState>(
      listenWhen: (prev, curr) =>
          prev.filterResetRevision != curr.filterResetRevision ||
          prev.locationUpdateRevision != curr.locationUpdateRevision ||
          prev.userLat != curr.userLat ||
          prev.userLng != curr.userLng,
      listener: (context, state) {
        if (_mapSearchCtrl.text.isNotEmpty && state.searchQuery.isEmpty) {
          setState(() => _mapSearchCtrl.clear());
        }
        _safeMoveMap(state.userLat, state.userLng, zoom: 15.0);
      },
      builder: (context, state) {
        final center = LatLng(state.userLat, state.userLng);

        return Column(
          children: [
            BarberSmartHeader(
              unreadCount: state.unreadNotificationCount,
              onNotificationTap: () async {
                await context.push('/notifications');
                if (context.mounted) {
                  context
                      .read<ShopDiscoveryCubit>()
                      .loadAll(userId: user?.id);
                }
              },
              onProfileSocialTap: () => context.push('/profile-social'),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14.8,
                      onMapReady: () {
                        _isMapReady = true;
                        final latest =
                            context.read<ShopDiscoveryCubit>().state;
                        _safeMoveMap(
                          latest.userLat,
                          latest.userLng,
                          zoom: 14.8,
                        );
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: AppConstants.osmTileUrl,
                        userAgentPackageName:
                            AppConstants.osmUserAgentPackage,
                      ),
                      MarkerLayer(
                        markers: [
                          // Marker vị trí GPS hiện tại của người dùng
                          Marker(
                            point: center,
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message: state.hasRealDeviceGps
                                  ? 'Vị trí GPS của bạn (${state.userLat.toStringAsFixed(4)}, ${state.userLng.toStringAsFixed(4)})'
                                  : 'Tâm mặc định Vạn Phúc, Hà Đông',
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blueAccent.withValues(alpha: 0.24),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Marker các quán cắt tóc kèm khoảng cách thực tế (km)
                          ...state.nearbyShops.map(
                            (shop) => _buildShopMarker(context, shop),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Thanh tìm kiếm + Nút Lọc nổi đè lên Map ở trên cùng
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.softCardShadow,
                                ),
                                child: TextField(
                                  controller: _mapSearchCtrl,
                                  onChanged: (q) {
                                    setState(() {});
                                    context
                                        .read<ShopDiscoveryCubit>()
                                        .updateSearch(q);
                                  },
                                  onSubmitted: (q) => context
                                      .read<ShopDiscoveryCubit>()
                                      .updateSearch(q),
                                  decoration: InputDecoration(
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppTheme.primaryGreen,
                                      size: 20,
                                    ),
                                    suffixIcon: _mapSearchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(
                                                () => _mapSearchCtrl.clear(),
                                              );
                                              context
                                                  .read<ShopDiscoveryCubit>()
                                                  .updateSearch('');
                                            },
                                          )
                                        : null,
                                    hintText: 'Tìm quán trên bản đồ...',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Lọc theo đánh giá & khoảng cách',
                              child: Material(
                                color: state.hasActiveFilter
                                    ? AppTheme.primaryGreen
                                    : AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(12),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => ShopFilterBottomSheet.show(
                                    context,
                                    userId: user?.id,
                                  ),
                                  child: SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: Icon(
                                      Icons.tune_rounded,
                                      color: state.hasActiveFilter
                                          ? Colors.white
                                          : AppTheme.primaryGreen,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: state.hasActiveFilter
                                  ? Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (state.minRatingFilter != null)
                                          _buildMapFilterBadge(
                                            'Từ ${state.minRatingFilter!.toStringAsFixed(1)} ⭐',
                                          ),
                                        if (state.maxDistanceKmFilter != null)
                                          _buildMapFilterBadge(
                                            '0 – ${state.maxDistanceKmFilter!.round()} km',
                                          ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Column(
                              children: [
                                _floatingCircleAction(
                                  icon: Icons.my_location_rounded,
                                  color: AppTheme.primaryGreen,
                                  onTap: _recenterToRealGps,
                                ),
                                const SizedBox(height: 8),
                                _floatingCircleAction(
                                  icon: Icons.layers_outlined,
                                  color: AppTheme.textSecondary,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          state.hasRealDeviceGps
                                              ? 'OSM đang lấy tâm GPS thật: (${state.userLat.toStringAsFixed(5)}, ${state.userLng.toStringAsFixed(5)})'
                                              : 'Bản đồ OpenStreetMap (OSM) — khu vực Vạn Phúc, Hà Đông',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Marker _buildShopMarker(BuildContext context, ShopEntity shop) {
    final shortName = shop.name.split(' - ').first;
    final distanceLabel = '${shop.distanceKm.toStringAsFixed(1)} km';
    return Marker(
      point: LatLng(shop.latitude, shop.longitude),
      width: 158,
      height: 92,
      child: GestureDetector(
        onTap: () => ShopDetailBottomSheet.show(context, shop: shop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: AppTheme.softCardShadow,
              ),
              child: const Icon(
                Icons.content_cut_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: AppTheme.softCardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 10,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        distanceLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapFilterBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _floatingCircleAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

