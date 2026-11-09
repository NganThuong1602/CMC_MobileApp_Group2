import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../shop/shop_detail_bottom_sheet.dart';

/// Màn hình Nổi bật chuẩn Pixel-perfect theo Ảnh 6:
/// - Danh sách các quán đang mua gói Nổi bật còn hiệu lực.
/// - Card ảnh to phủ toàn bộ, gradient đen dưới đáy, tên quán góc trái dưới,
///   nút `Đặt lịch` góc phải dưới.
class HighlightsPage extends StatelessWidget {
  final VoidCallback onNavigateToMapTab;

  const HighlightsPage({
    super.key,
    required this.onNavigateToMapTab,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final user = context.watch<AuthCubit>().state.user;

    return BlocBuilder<ShopDiscoveryCubit, ShopDiscoveryState>(
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
            Expanded(
              child: RefreshIndicator(
                color: cs.primary,
                onRefresh: () => context
                    .read<ShopDiscoveryCubit>()
                    .loadAll(userId: user?.id),
                child: state.highlightedShops.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Hiện chưa có quán nào kích hoạt gói Nổi bật.',
                              style: tt.bodyMuted,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.highlightedShops.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (ctx, i) => _buildHighlightBannerCard(
                          context,
                          state.highlightedShops[i],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightBannerCard(BuildContext context, ShopEntity shop) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return GestureDetector(
      onTap: () => ShopDetailBottomSheet.show(
        context,
        shop: shop,
        onDirectionsTap: onNavigateToMapTab,
      ),
      child: Container(
        height: 176,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: appColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              shop.coverImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: cs.inverseSurface,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    appColors.bannerOverlayTop,
                    appColors.bannerOverlayBottom,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      shop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bannerOverlayTitle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => context.push('/booking/${shop.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Đặt lịch',
                      style: tt.buttonLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
