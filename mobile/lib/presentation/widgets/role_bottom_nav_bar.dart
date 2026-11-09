import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/enums/app_enums.dart';
import '../../core/theme/app_theme.dart';

/// Thanh Bottom Navigation Bar linh hoạt theo Role:
/// - Role USER: 4 tab (`Trang chủ`, `Bản đồ`, `Nổi bật`, `Hồ Sơ`)
/// - Role MANAGER: 5 tab, ở giữa có nút tròn to lồi lên + text `Quản lý`
/// - Role BARBER: 5 tab, ở giữa có nút tròn to lồi lên + text `Lịch`
/// - Role ADMIN: 5 tab, ở giữa có nút tròn to lồi lên + text `Admin`
/// Toàn bộ màu sắc & kiểu chữ được kế thừa tự động từ [AppTheme].
class RoleBottomNavBar extends StatelessWidget {
  final UserRole role;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const RoleBottomNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final appColors = context.appColors;
    final ts = context.appTextStyles;
    final hasCenterFab = role == UserRole.manager ||
        role == UserRole.barber ||
        role == UserRole.admin;
    final bottomInset =
        kIsWeb ? 0.0 : math.min(MediaQuery.paddingOf(context).bottom, 16.0);

    if (!hasCenterFab) {
      return Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _buildTabItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Trang chủ',
              ),
              _buildTabItem(
                context,
                index: 1,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Bản đồ',
              ),
              _buildTabItem(
                context,
                index: 2,
                icon: Icons.local_fire_department_outlined,
                activeIcon: Icons.local_fire_department_rounded,
                label: 'Nổi bật',
              ),
              _buildTabItem(
                context,
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Hồ Sơ',
              ),
            ],
          ),
        ),
      );
    }

    final centerIcon = switch (role) {
      UserRole.manager => Icons.storefront_rounded,
      UserRole.barber => Icons.calendar_today_rounded,
      UserRole.admin => Icons.admin_panel_settings_rounded,
      UserRole.user => Icons.storefront_rounded,
    };
    final centerLabel = switch (role) {
      UserRole.manager => 'Quản lý',
      UserRole.barber => 'Lịch',
      UserRole.admin => 'Admin',
      UserRole.user => 'Quản lý',
    };
    final isCenterSelected = currentIndex == 2;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: SizedBox(
        height: 62,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                _buildTabItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Trang chủ',
                ),
                _buildTabItem(
                  context,
                  index: 1,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: 'Bản đồ',
                ),
                const Expanded(child: SizedBox()),
                _buildTabItem(
                  context,
                  index: 3,
                  icon: Icons.local_fire_department_outlined,
                  activeIcon: Icons.local_fire_department_rounded,
                  label: 'Nổi bật',
                ),
                _buildTabItem(
                  context,
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Hồ Sơ',
                ),
              ],
            ),
            Positioned(
              top: -20,
              child: GestureDetector(
                onTap: () => onTabSelected(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 3.5),
                        boxShadow: isCenterSelected
                            ? appColors.primaryStrongGlowShadow
                            : appColors.primaryGlowShadow,
                      ),
                      child: Icon(
                        centerIcon,
                        color: cs.onPrimary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerLabel,
                      style: ts.tabActive,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final cs = context.colorScheme;
    final ts = context.appTextStyles;
    final isSelected = currentIndex == index;
    final color = isSelected ? cs.primary : cs.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: isSelected ? ts.tabActive : ts.tabInactive,
            ),
          ],
        ),
      ),
    );
  }
}
