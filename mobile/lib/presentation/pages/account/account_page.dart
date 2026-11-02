import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Tài khoản / Hồ Sơ chuẩn Pixel-perfect theo Ảnh 7:
/// - Avatar tròn to chính giữa kèm huy hiệu tích xanh `#00A859`.
/// - Họ tên đậm + Pill `Thành viên thân thiết`.
/// - 3 Card trắng: `Thông báo`, `Lịch đã đặt` (Hủy lịch), `Đăng ký quán` (lên đời Manager qua SePay 100k).
/// - Nút chữ đỏ `Đăng xuất` (dọn sạch session, bắn state Unauthenticated để GoRouter redirect thẳng `/login`).
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    final avatarUrl =
        (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
            ? user.avatarUrl!
            : AppConstants.defaultAvatarUrl;

    final badgeLabel = switch (user.role) {
      UserRole.manager => 'Chủ tiệm • Quản lý quán',
      UserRole.barber => 'Barber chuyên nghiệp',
      UserRole.user => 'Thành viên thân thiết',
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
                  // Khối thông tin Avatar tròn to + tích xanh + Tên + Badge
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
                                color: Colors.white,
                                boxShadow: AppTheme.softCardShadow,
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFE5E7EB),
                                backgroundImage: NetworkImage(avatarUrl),
                                onBackgroundImageError: (_, __) {},
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0F8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Chạm vào ảnh để mở Trang cá nhân & Mạng xã hội',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMenuCard(
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
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Lịch đã đặt',
                    subtitle: 'Quản lý các cuộc hẹn sắp tới & Hủy lịch',
                    onTap: () => context.push('/my-bookings'),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.storefront_outlined,
                    title: 'Đăng ký quán',
                    subtitle: 'Mở rộng kinh doanh cùng BarberSmart',
                    onTap: () => context.push('/register-shop'),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.read<AuthCubit>().logout(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreenLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showDot)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

