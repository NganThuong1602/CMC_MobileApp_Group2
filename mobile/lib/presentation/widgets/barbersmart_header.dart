import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Header chuẩn Pixel-perfect theo Màn hình 3, 5, 6, 7, 9, 10:
/// - Trái: Text xanh đậm `BARBERSMART`
/// - Phải: Chuông thông báo kèm badge đỏ đếm số + Nút tròn xanh icon User (mở Trang cá nhân Mạng xã hội)
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
    return Container(
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
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
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.textPrimary,
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
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
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
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

