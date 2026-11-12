import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/auth/auth_cubit.dart';

/// Header chuẩn Pixel-perfect theo Màn hình 3, 5, 6, 7, 9, 10:
/// - Trái: Text chủ đạo `BARBERSMART`
/// - Phải: Chuông thông báo kèm badge đếm số + Avatar tài khoản đang đăng nhập (mở Trang cá nhân Mạng xã hội)
/// Toàn bộ màu sắc & kiểu chữ kế thừa tự động từ [AppTheme].
class BarberSmartHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileSocialTap;
  final String? avatarUrl;

  const BarberSmartHeader({
    super.key,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onProfileSocialTap,
    this.avatarUrl,
  });

  String? _resolveAvatarUrl(BuildContext context) {
    final explicit = avatarUrl?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    try {
      return context.select<AuthCubit, String?>((cubit) {
        final user = cubit.state.user;
        if (user == null) return null;
        final raw = user.avatarUrl?.trim() ?? '';
        return raw.isNotEmpty ? raw : AppConstants.defaultAvatarUrl;
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.appTextStyles;
    final resolvedAvatarUrl = _resolveAvatarUrl(context);

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Text(
            AppConstants.appName,
            style: ts.headerBrand,
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onNotificationTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: cs.onSurface,
                    size: 26,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: ts.badgeOnPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onProfileSocialTap,
            child: _HeaderAvatar(avatarUrl: resolvedAvatarUrl),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị ảnh avatar tròn của tài khoản đang đăng nhập và fallback về icon mặc định khi chưa có ảnh hoặc tải lỗi.
class _HeaderAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _HeaderAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final fallback = Container(
      color: cs.primary,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        color: cs.onPrimary,
        size: 20,
      ),
    );

    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
        border: hasAvatar
            ? Border.all(
                color: cs.primary.withValues(alpha: 0.45),
                width: 1.5,
              )
            : null,
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                loadingBuilder: (context, child, loadingProgress) =>
                    loadingProgress == null ? child : fallback,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
