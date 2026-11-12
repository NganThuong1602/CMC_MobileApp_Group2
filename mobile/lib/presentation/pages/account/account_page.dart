import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Tài khoản / Hồ Sơ chuẩn Pixel-perfect:
/// - Avatar tròn to chính giữa kèm huy hiệu tích xanh.
/// - Họ tên đậm + Pill vai trò tài khoản.
/// - 3 Card: `Thông báo`, `Lịch đã đặt`, `Đăng ký quán` (làm mờ khi đã là Manager/Admin hoặc đang có quán Chờ duyệt).
/// - Nút `Đăng xuất`.
class AccountPage extends StatefulWidget {
  final bool isActiveTab;

  const AccountPage({super.key, this.isActiveTab = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  ShopEntity? _ownedOrPendingShop;
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthCubit>().state.user;
    if (user != null && _loadedUserId != user.id) {
      _loadedUserId = user.id;
      _checkOwnedOrPendingShop(user.id);
    }
  }

  @override
  void didUpdateWidget(covariant AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        _checkOwnedOrPendingShop(user.id);
      }
    }
  }

  Future<void> _checkOwnedOrPendingShop(String userId) async {
    final res = await sl<ShopRepository>().getShopByOwnerId(userId);
    if (!mounted) return;
    setState(() {
      _ownedOrPendingShop = res.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final user = context.watch<AuthCubit>().state.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final avatarUrl =
        (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
            ? user.avatarUrl!
            : AppConstants.defaultAvatarUrl;

    final badgeLabel = switch (user.role) {
      UserRole.manager => 'Chủ tiệm • Quản lý quán',
      UserRole.barber => 'Barber chuyên nghiệp',
      UserRole.admin => 'Quản trị viên hệ thống (Admin)',
      UserRole.user => 'Thành viên thân thiết',
    };

    final hasPendingShop =
        _ownedOrPendingShop != null && !_ownedOrPendingShop!.isActive;
    final hasApprovedShop = user.role == UserRole.manager ||
        (_ownedOrPendingShop != null && _ownedOrPendingShop!.isActive);
    final isRegisterShopDisabled =
        user.role == UserRole.admin || user.role == UserRole.barber;

    final registerShopSubtitle = switch (user.role) {
      UserRole.manager => 'Hồ sơ quán đã được duyệt',
      UserRole.admin =>
        'Tài khoản Admin chuyên trách phê duyệt & quản trị hệ thống',
      UserRole.barber =>
        'Tài khoản đang là Barber chính thức tại quán',
      UserRole.user => hasPendingShop
          ? 'Quán "${_ownedOrPendingShop!.name}" đang Chờ duyệt'
          : hasApprovedShop
              ? 'Quán "${_ownedOrPendingShop!.name}" đã được duyệt'
              : 'Mở rộng kinh doanh cùng BarberSmart',
    };

    return BlocBuilder<ShopDiscoveryCubit, ShopDiscoveryState>(
      builder: (context, discoveryState) {
        return Column(
          children: [
            BarberSmartHeader(
              unreadCount: discoveryState.unreadNotificationCount,
              onNotificationTap: () async {
                await context.push('/notifications');
                if (context.mounted) {
                  context
                      .read<ShopDiscoveryCubit>()
                      .loadAll(userId: user.id);
                  _checkOwnedOrPendingShop(user.id);
                }
              },
              onProfileSocialTap: () => context.push('/profile-social'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile-social'),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.surface,
                                boxShadow: appColors.cardShadow,
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: cs.surfaceContainerHighest,
                                backgroundImage: NetworkImage(avatarUrl),
                                onBackgroundImageError: (_, __) {},
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: Tooltip(
                                message: badgeLabel,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Icon(
                                    user.role.roleIcon,
                                    size: 15,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.fullName,
                          style: tt.pageTitle,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badgeLabel,
                            style: tt.badgeSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.notifications_none_rounded,
                    title: 'Thông báo',
                    subtitle: 'Cập nhật lịch hẹn và ưu đãi',
                    showDot: discoveryState.unreadNotificationCount > 0,
                    onTap: () async {
                      await context.push('/notifications');
                      if (context.mounted) {
                        context
                            .read<ShopDiscoveryCubit>()
                            .loadAll(userId: user.id);
                        _checkOwnedOrPendingShop(user.id);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    title: 'Lịch đã đặt',
                    subtitle: 'Quản lý các cuộc hẹn sắp tới & Hủy lịch',
                    onTap: () => context.push('/my-bookings'),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: isRegisterShopDisabled ? 0.45 : 1.0,
                    child: _buildMenuCard(
                      context: context,
                      icon: Icons.storefront_outlined,
                      title: 'Đăng ký quán',
                      subtitle: registerShopSubtitle,
                      disabled: isRegisterShopDisabled,
                      statusBadgeText: hasPendingShop
                          ? 'Chờ duyệt'
                          : (hasApprovedShop ? 'Đã duyệt' : null),
                      isApprovedBadge: hasApprovedShop && !hasPendingShop,
                      onTap: () async {
                        if (isRegisterShopDisabled) return;
                        await context.push('/register-shop');
                        if (context.mounted) {
                          _checkOwnedOrPendingShop(user.id);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.read<AuthCubit>().logout(),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        'Đăng xuất',
                        style: tt.buttonLabelDanger,
                      ),
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

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDot = false,
    bool disabled = false,
    String? statusBadgeText,
    bool isApprovedBadge = false,
  }) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: appColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.cardTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: tt.bodySmallMuted,
                    ),
                  ],
                ),
              ),
              if (statusBadgeText != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isApprovedBadge
                        ? cs.primaryContainer
                        : appColors.warningContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusBadgeText,
                    style: tt.badgePrimary,
                  ),
                ),
              if (showDot)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: appColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              Icon(
                disabled ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: disabled ? 19 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
