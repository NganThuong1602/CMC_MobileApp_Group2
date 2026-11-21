import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/finance_entities.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../../widgets/shop_filter_bottom_sheet.dart';
import '../shop/shop_detail_bottom_sheet.dart';

/// Màn hình Trang chủ chuẩn Pixel-perfect theo Ảnh 3:
/// - Popup hỏi quyền Vị trí & Popup Banner Sale % (kiểu Shopee) cho role USER khi có mã giảm giá từ Admin.
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
  static String? _shownSalePopupUserId;
  static StreamSubscription<AuthState>? _authResetSub;

  final _searchCtrl = TextEditingController();
  bool _checkingSalePopup = false;

  @override
  void initState() {
    super.initState();
    _ensureAuthResetWatcher();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAndShowAdminSaleBannerPopup());
      unawaited(_promptLocationPermissionIfNeeded());
    });
  }

  void _ensureAuthResetWatcher() {
    if (_authResetSub != null || !sl.isRegistered<AuthCubit>()) return;
    _authResetSub = sl<AuthCubit>().stream.listen((authState) {
      if (!authState.isAuthenticated) {
        _shownSalePopupUserId = null;
      }
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

  Future<void> _checkAndShowAdminSaleBannerPopup() async {
    if (!mounted || _checkingSalePopup) return;
    final user = context.read<AuthCubit>().state.user;
    if (user == null || user.role != UserRole.user) return;
    if (_shownSalePopupUserId == user.id) return;

    _checkingSalePopup = true;
    try {
      int bestPercent = 0;
      String bestTitle = '';

      if (sl.isRegistered<ShopRepository>()) {
        final res = await sl<ShopRepository>().getDiscountCodes();
        final list = res.data ?? const <DiscountCodeEntity>[];
        final now = DateTime.now();
        final activeToday = list.where((d) {
          if (!d.isActive) return false;
          if (d.isActiveAt(now)) return true;
          final sameDayStart = d.startAt.year == now.year &&
              d.startAt.month == now.month &&
              d.startAt.day == now.day;
          return sameDayStart && !d.endAt.isBefore(now);
        }).toList()
          ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));

        if (activeToday.isNotEmpty) {
          bestPercent = activeToday.first.discountPercent;
          bestTitle = activeToday.first.name;
        }
      }

      if (!mounted) return;
      if (bestPercent <= 0) {
        final discoveryState = context.read<ShopDiscoveryCubit>().state;
        final allShops = [
          ...discoveryState.allNearbyShops,
          ...discoveryState.nearbyShops,
          ...discoveryState.highlightedShops,
        ];
        for (final s in allShops) {
          if (s.activeDiscountPercent > bestPercent) {
            bestPercent = s.activeDiscountPercent;
            bestTitle = s.activeDiscountName;
          }
        }
      }

      if (bestPercent <= 0 || !mounted) return;
      _shownSalePopupUserId = user.id;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          final cs = dialogCtx.colorScheme;
          final tt = dialogCtx.appTextStyles;
          final appColors = dialogCtx.appColors;

          void goToHighlightedShops() {
            Navigator.of(dialogCtx).pop();
            if (!mounted) return;
            final cubit = context.read<ShopDiscoveryCubit>();
            if (!cubit.state.onlyHighlightedFilter) {
              cubit.toggleHighlightedFilter(userId: user.id);
            }
          }

          return Dialog(
            backgroundColor: cs.surface.withValues(alpha: 0),
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: goToHighlightedShops,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.error, width: 2.5),
                      boxShadow: appColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.error,
                                cs.primary,
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 16,
                                      color: cs.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SIÊU SALE HÔM NAY',
                                      style: tt.badgeDanger,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'SALE $bestPercent%',
                                textAlign: TextAlign.center,
                                style: tt.heroPriceOnPrimary,
                              ),
                              if (bestTitle.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  bestTitle.trim(),
                                  textAlign: TextAlign.center,
                                  style: tt.bodyOnPrimary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Text(
                                'Giảm ngay $bestPercent% toàn bộ dịch vụ cắt tóc tại các Quán Nổi Bật!',
                                textAlign: TextAlign.center,
                                style: tt.bodyStrong,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: goToHighlightedShops,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.error,
                                    foregroundColor: cs.onError,
                                  ),
                                  icon: const Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Săn sale tại Quán Nổi Bật ngay',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                IconButton.filled(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.inverseSurface,
                    foregroundColor: cs.onInverseSurface,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Đóng',
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _checkingSalePopup = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final user = context.watch<AuthCubit>().state.user;

    return BlocConsumer<ShopDiscoveryCubit, ShopDiscoveryState>(
      listenWhen: (prev, curr) =>
          prev.filterResetRevision != curr.filterResetRevision ||
          (prev.allNearbyShops.length != curr.allNearbyShops.length &&
              curr.allNearbyShops.isNotEmpty) ||
          (prev.nearbyShops.length != curr.nearbyShops.length &&
              curr.nearbyShops.isNotEmpty),
      listener: (context, state) {
        if (_searchCtrl.text.isNotEmpty && !state.hasActiveFilter && state.searchQuery.isEmpty) {
          setState(() => _searchCtrl.clear());
        }
        unawaited(_checkAndShowAdminSaleBannerPopup());
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
