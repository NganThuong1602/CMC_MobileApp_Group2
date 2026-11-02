import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/role_bottom_nav_bar.dart';
import '../account/account_page.dart';
import '../barber/barber_hub_page.dart';
import '../highlights/highlights_page.dart';
import '../home/home_page.dart';
import '../manager/my_shop_page.dart';
import '../map/map_page.dart';

/// Khung điều hướng chính (Main Shell) tự động thay đổi 4 hoặc 5 Tab dựa theo Role hiện tại:
/// - USER: [Trang chủ, Bản đồ, Nổi bật, Hồ Sơ]
/// - MANAGER: [Trang chủ, Bản đồ, Quản lý (FAB tròn lồi), Nổi bật, Hồ Sơ]
/// - BARBER: [Trang chủ, Bản đồ, Lịch (FAB tròn lồi), Nổi bật, Hồ Sơ]
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;

    // Tuyệt đối không trả về SizedBox.shrink() gây trắng màn hình khi vừa bấm Đăng xuất
    if (!authState.isAuthenticated || user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return BlocProvider<ShopDiscoveryCubit>(
      create: (_) => sl<ShopDiscoveryCubit>()..loadAll(userId: user.id),
      child: Builder(
        builder: (context) {
          final pages = _buildPagesForRole(context, user.role, user.id);
          final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: safeIndex,
                children: pages,
              ),
            ),
            bottomNavigationBar: RoleBottomNavBar(
              role: user.role,
              currentIndex: safeIndex,
              onTabSelected: (idx) {
                final prevIndex = safeIndex;
                setState(() => _currentIndex = idx);
                // Khi chuyển qua lại giữa Trang chủ (0) và Bản đồ (1), tự động xoá sạch filter/tìm kiếm cũ
                if (prevIndex != idx &&
                    (idx == 0 || idx == 1 || prevIndex == 0 || prevIndex == 1)) {
                  context
                      .read<ShopDiscoveryCubit>()
                      .resetAllSearchAndFiltersOnTabSwitch(userId: user.id);
                } else {
                  context.read<ShopDiscoveryCubit>().loadAll(userId: user.id);
                }
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPagesForRole(
    BuildContext innerContext,
    UserRole role,
    String userId,
  ) {
    void goToMap() {
      if (_currentIndex != 1) {
        setState(() => _currentIndex = 1);
        innerContext
            .read<ShopDiscoveryCubit>()
            .resetAllSearchAndFiltersOnTabSwitch(userId: userId);
      }
    }

    switch (role) {
      case UserRole.user:
        return [
          HomePage(onNavigateToMapTab: goToMap),
          const MapPage(),
          HighlightsPage(onNavigateToMapTab: goToMap),
          const AccountPage(),
        ];
      case UserRole.manager:
        return [
          HomePage(onNavigateToMapTab: goToMap),
          const MapPage(),
          const MyShopPage(),
          HighlightsPage(onNavigateToMapTab: goToMap),
          const AccountPage(),
        ];
      case UserRole.barber:
        return [
          HomePage(onNavigateToMapTab: goToMap),
          const MapPage(),
          const BarberHubPage(),
          HighlightsPage(onNavigateToMapTab: goToMap),
          const AccountPage(),
        ];
    }
  }
}
