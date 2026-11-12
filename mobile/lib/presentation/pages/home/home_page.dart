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
    await cubit.requestRealDeviceLocation(userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
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
              color: cs.surface,
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
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: cs.onSurfaceVariant,
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
                                  ? cs.primary
                                  : cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        avatar: Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: !state.onlyHighlightedFilter
                              ? cs.onPrimary
                              : cs.primary,
                        ),
                        label: Text(
                          'Tất cả',
                          style: !state.onlyHighlightedFilter
                              ? tt.bodySmallOnPrimary
                              : tt.bodySmallStrong,
                        ),
                        selected: !state.onlyHighlightedFilter,
                        selectedColor: cs.primary,
                        backgroundColor: cs.surfaceContainer,
                        showCheckmark: false,
                        onSelected: (_) {
                          if (state.onlyHighlightedFilter) {
                            context
                                .read<ShopDiscoveryCubit>()
                                .toggleHighlightedFilter(userId: user?.id);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: state.onlyHighlightedFilter
                              ? cs.onPrimary
                              : cs.primary,
                        ),
                        label: Text(
                          'Nổi bật',
                          style: state.onlyHighlightedFilter
                              ? tt.bodySmallOnPrimary
                              : tt.bodySmallStrong,
                        ),
                        selected: state.onlyHighlightedFilter,
                        selectedColor: cs.primary,
                        backgroundColor: cs.surfaceContainer,
                        showCheckmark: false,
                        onSelected: (_) {
                          if (!state.onlyHighlightedFilter) {
                            context
                                .read<ShopDiscoveryCubit>()
                                .toggleHighlightedFilter(userId: user?.id);
                          }
                        },
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
                            context,
                            'Từ ${state.minRatingFilter!.toStringAsFixed(1)} ⭐',
                          ),
                        if (state.maxDistanceKmFilter != null)
                          _buildActiveFilterPill(
                            context,
                            '0 – ${state.maxDistanceKmFilter!.round()} km',
                          ),
                        InkWell(
                          onTap: () => context
                              .read<ShopDiscoveryCubit>()
                              .clearFilters(userId: user?.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Xoá lọc',
                              style: tt.bodySmallDanger,
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
                      child: CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () => context
                          .read<ShopDiscoveryCubit>()
                          .loadAll(userId: user?.id),
                      child: state.nearbyShops.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Không tìm thấy tiệm cắt tóc phù hợp.',
                                    style: tt.bodyMuted,
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

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
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: appColors.cardShadow,
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
                      color: cs.primaryContainer,
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                if (shop.isHighlightedAt(DateTime.now()) ||
                    shop.activeDiscountPercent > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (shop.isHighlightedAt(DateTime.now()))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 14,
                                  color: cs.onPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Nổi bật',
                                  style: tt.badgeOnPrimary,
                                ),
                              ],
                            ),
                          ),
                        if (shop.activeDiscountPercent > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Giảm ${shop.activeDiscountPercent}%',
                              style: tt.badgeOnPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (shop.hasRating)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.translucentSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: appColors.starRating,
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            shop.rating.toStringAsFixed(1),
                            style: tt.bodySmallStrong,
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
                    style: tt.cardTitleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 15,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppFormatters.formatDistanceKm(shop.distanceKm),
                        style: tt.bodySmallMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${shop.openTime} - ${shop.closeTime}',
                        style: tt.bodySmallMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_in_talk_outlined,
                        size: 15,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Liên hệ: ',
                        style: tt.bodySmallMuted,
                      ),
                      Text(
                        shop.phone,
                        style: tt.bodySmallStrong,
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

  Widget _buildActiveFilterPill(BuildContext context, String text) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: tt.badgePrimary,
      ),
    );
  }
}
