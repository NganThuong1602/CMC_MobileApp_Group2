import 'package:flutter/material.dart';
import '../../core/enums/app_enums.dart';
import '../../core/theme/app_theme.dart';

/// Thanh Bottom Navigation Bar linh hoạt theo Role (Ảnh 3, 5, 6, 7, 9, 10):
/// - Role USER: 4 tab (`Trang chủ`, `Bản đồ`, `Nổi bật`, `Hồ Sơ`)
/// - Role MANAGER (Ảnh 9): 5 tab, ở giữa có nút tròn to lồi lên màu xanh `#00A859` + text `Quản lý`
/// - Role BARBER (Ảnh 10): 5 tab, ở giữa có nút tròn to lồi lên màu xanh `#00A859` + text `Lịch`
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
    final hasCenterFab = role == UserRole.manager || role == UserRole.barber;

    if (!hasCenterFab) {
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _buildTabItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Trang chủ',
                ),
                _buildTabItem(
                  index: 1,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: 'Bản đồ',
                ),
                _buildTabItem(
                  index: 2,
                  icon: Icons.local_fire_department_outlined,
                  activeIcon: Icons.local_fire_department_rounded,
                  label: 'Nổi bật',
                ),
                _buildTabItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Hồ Sơ',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final centerIcon = role == UserRole.manager
        ? Icons.storefront_rounded
        : Icons.calendar_today_rounded;
    final centerLabel = role == UserRole.manager ? 'Quản lý' : 'Lịch';
    final isCenterSelected = currentIndex == 2;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  _buildTabItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Trang chủ',
                  ),
                  _buildTabItem(
                    index: 1,
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: 'Bản đồ',
                  ),
                  const Expanded(child: SizedBox()),
                  _buildTabItem(
                    index: 3,
                    icon: Icons.local_fire_department_outlined,
                    activeIcon: Icons.local_fire_department_rounded,
                    label: 'Nổi bật',
                  ),
                  _buildTabItem(
                    index: 4,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Hồ Sơ',
                  ),
                ],
              ),
              Positioned(
                top: -22,
                child: GestureDetector(
                  onTap: () => onTabSelected(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: isCenterSelected ? 0.42 : 0.25,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          centerIcon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        centerLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCenterSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    final color =
        isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary;

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
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

