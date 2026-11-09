import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Header chuẩn Pixel-perfect theo Màn hình 3, 5, 6, 7, 9, 10:
/// - Trái: Text chủ đạo `BARBERSMART`
/// - Phải: Chuông thông báo kèm badge đếm số + Nút tròn icon User (mở Trang cá nhân Mạng xã hội)
/// Toàn bộ màu sắc & kiểu chữ kế thừa tự động từ [AppTheme].
class BarberSmartHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileSocialTap;

  const BarberSmartHeader({
    super.key,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onProfileSocialTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.appTextStyles;

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
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: cs.onPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
