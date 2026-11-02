import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../../widgets/shop_filter_bottom_sheet.dart';
import '../shop/shop_detail_bottom_sheet.dart';

/// Màn hình Trang chủ chuẩn Pixel-perfect theo Ảnh 3:
/// - Popup hỏi quyền Vị trí khi mới vào Trang chủ.
/// - Header BARBERSMART + chuông đỏ + avatar tròn xanh + Thanh tìm kiếm & nút Filter.
/// - Danh sách Card quán lân cận (Ảnh bìa to, Badge sao góc phải trên, Khoảng cách, Giờ mở cửa, Liên hệ).
class HomePage extends StatefulWidget {
  final VoidCallback onNavigateToMapTab;

  const HomePage({
    super.key,
    required this.onNavigateToMapTab,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptLocationPermissionIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptLocationPermissionIfNeeded() async {
    if (!mounted) return;
    final cubit = context.read<ShopDiscoveryCubit>();
    if (cubit.state.locationPermissionAsked) return;
    final userId = context.read<AuthCubit>().state.user?.id;
    // Gọi trực tiếp Geolocator để bật popup xin quyền GPS thực tế của hệ điều hành / trình duyệt
    await cubit.requestRealDeviceLocation(userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    return BlocConsumer<ShopDiscoveryCubit, ShopDiscoveryState>(
      listenWhen: (prev, curr) =>
          prev.filterResetRevision != curr.filterResetRevision,
      listener: (context, state) {
        if (_searchCtrl.text.isNotEmpty) {
          setState(() => _searchCtrl.clear());
        }
      },
      builder: (context, state) {
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
            Container(
              color: AppTheme.surfaceWhite,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) {
                              setState(() {});
                              context
                                  .read<ShopDiscoveryCubit>()
                                  .updateSearch(v);
                            },
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm tiệm cắt tóc...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() => _searchCtrl.clear());
                                        context
                                            .read<ShopDiscoveryCubit>()
                                            .updateSearch('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: state.hasRealDeviceGps
                            ? 'Đã kết nối GPS thật (${state.userLat.toStringAsFixed(4)}, ${state.userLng.toStringAsFixed(4)})'
                            : 'Cập nhật vị trí GPS thực tế',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context
                              .read<ShopDiscoveryCubit>()
                              .requestRealDeviceLocation(userId: user?.id),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: state.hasRealDeviceGps
                                  ? AppTheme.primaryGreen
                                  : AppTheme.primaryGreenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.my_location_rounded,
                              color: state.hasRealDeviceGps
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Lọc theo đánh giá & khoảng cách',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => ShopFilterBottomSheet.show(
                            context,
                            userId: user?.id,
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: state.hasActiveFilter
                                  ? AppTheme.primaryGreen
                                  : AppTheme.primaryGreenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                    ],
                  ),
                  if (state.hasActiveFilter) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (state.minRatingFilter != null)
                          _buildActiveFilterPill(
                            'Từ ${state.minRatingFilter!.toStringAsFixed(1)} ⭐',
                          ),
                        if (state.maxDistanceKmFilter != null)
                          _buildActiveFilterPill(
                            '0 – ${state.maxDistanceKmFilter!.round()} km',
                          ),
                        InkWell(
                          onTap: () => context
                              .read<ShopDiscoveryCubit>()
                              .clearFilters(userId: user?.id),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Xoá lọc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: state.isLoading && state.nearbyShops.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryGreen,
                      onRefresh: () => context
                          .read<ShopDiscoveryCubit>()
                          .loadAll(userId: user?.id),
                      child: state.nearbyShops.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Không tìm thấy tiệm cắt tóc phù hợp.',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: state.nearbyShops.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (ctx, i) => _buildShopCard(
                                context,
                                state.nearbyShops[i],
                              ),
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShopCard(BuildContext context, ShopEntity shop) {
    return GestureDetector(
      onTap: () {
        ShopDetailBottomSheet.show(
          context,
          shop: shop,
          onDirectionsTap: widget.onNavigateToMapTab,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softCardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9.5,
                  child: Image.network(
                    shop.coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryGreenLight,
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB300),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          shop.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 15,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppFormatters.formatDistanceKm(shop.distanceKm),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${shop.openTime} - ${shop.closeTime}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_in_talk_outlined,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Liên hệ: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        shop.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
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

  Widget _buildActiveFilterPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreenLight,
        borderRadius: BorderRadius.circular(20),
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
}

