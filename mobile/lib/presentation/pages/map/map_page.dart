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
/// - Các Marker hình Cái kéo + nhãn hiển thị Tên quán & Khoảng cách thực tế (`km`).
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ShopDiscoveryCubit>();
      if (!cubit.state.hasRealDeviceGps) {
        final userId = context.read<AuthCubit>().state.user?.id;
        cubit.requestRealDeviceLocation(userId: userId);
      }
    });
  }

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
    final cs = context.colorScheme;
    final appColors = context.appColors;
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
                          _buildUserLocationMarker(context, state),
                          ...state.nearbyShops.map(
                            (shop) => _buildShopMarker(context, shop),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: appColors.cardShadow,
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
                                    fillColor: AppTheme.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: cs.primary,
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
                                    ? cs.primary
                                    : cs.surface,
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
                                          ? cs.onPrimary
                                          : cs.primary,
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
                                            context,
                                            'Từ ${state.minRatingFilter!.toStringAsFixed(1)} ⭐',
                                          ),
                                        if (state.maxDistanceKmFilter != null)
                                          _buildMapFilterBadge(
                                            context,
                                            '0 – ${state.maxDistanceKmFilter!.round()} km',
                                          ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Column(
                              children: [
                                _floatingCircleAction(
                                  context: context,
                                  icon: Icons.my_location_rounded,
                                  color: cs.primary,
                                  onTap: _recenterToRealGps,
                                ),
                                const SizedBox(height: 8),
                                _floatingCircleAction(
                                  context: context,
                                  icon: Icons.layers_outlined,
                                  color: cs.onSurfaceVariant,
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

  Marker _buildUserLocationMarker(
    BuildContext context,
    ShopDiscoveryState state,
  ) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Marker(
      point: LatLng(state.userLat, state.userLng),
      width: 136,
      height: 82,
      child: Tooltip(
        message:
            'Vị trí của bạn (${state.userLat.toStringAsFixed(5)}, ${state.userLng.toStringAsFixed(5)})',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: appColors.info,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2.5),
                boxShadow: appColors.cardShadow,
              ),
              child: Icon(
                Icons.person_pin_circle_rounded,
                color: cs.onPrimary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: appColors.info,
                borderRadius: BorderRadius.circular(10),
                boxShadow: appColors.cardShadow,
              ),
              child: Text(
                'Vị trí của bạn',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.badgeOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildShopMarker(BuildContext context, ShopEntity shop) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
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
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2.5),
                boxShadow: appColors.cardShadow,
              ),
              child: Icon(
                Icons.content_cut_rounded,
                color: cs.onPrimary,
                size: 17,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(9),
                boxShadow: appColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.captionStrong,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 10,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        distanceLabel,
                        style: tt.badgePrimary,
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

  Widget _buildMapFilterBadge(BuildContext context, String text) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appColors.cardShadow,
      ),
      child: Text(
        text,
        style: tt.badgePrimary,
      ),
    );
  }

  Widget _floatingCircleAction({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = context.colorScheme;
    return Material(
      color: cs.surface,
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
