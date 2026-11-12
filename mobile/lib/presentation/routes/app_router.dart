import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_cubit.dart';
import '../pages/account/my_bookings_page.dart';
import '../pages/account/notifications_page.dart';
import '../pages/account/profile_social_page.dart';
import '../pages/account/register_shop_page.dart';
import '../pages/auth/auth_page.dart';
import '../pages/booking/booking_flow_page.dart';
import '../pages/chat/group_chat_page.dart';
import '../pages/main/main_shell_page.dart';

/// Adapter giúp GoRouter lắng nghe trực tiếp mọi biến đổi state của [AuthCubit]
/// (đặc biệt khi chuyển về `AuthStatus.unauthenticated` lúc bấm Đăng xuất).
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: authCubit.state.isAuthenticated ? '/' : '/login',
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
      redirect: (context, state) {
        final loggedIn = authCubit.state.isAuthenticated;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == '/login' || loc == '/auth';

        // Bắt buộc đăng nhập/đăng ký khi chưa xác thực hoặc vừa bấm Đăng xuất -> chuyển thẳng về /login
        if (!loggedIn) {
          if (loc == '/auth') return '/login';
          return isAuthRoute ? null : '/login';
        }

        // Đã đăng nhập mà đang ở trang /login -> đẩy thẳng vào Trang chủ /
        if (loggedIn && isAuthRoute) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const AuthPage(),
        ),
        GoRoute(
          path: '/auth',
          redirect: (_, __) => '/login',
        ),
        GoRoute(
          path: '/',
          builder: (context, state) {
            final tabParam = int.tryParse(
              state.uri.queryParameters['tab'] ?? '',
            );
            final openConsult =
                state.uri.queryParameters['openConsult'] == '1';
            final roomId = state.uri.queryParameters['roomId'];
            final customerHint = state.uri.queryParameters['customerHint'];
            final requestToken = state.uri.queryParameters['ts'];
            return MainShellPage(
              requestedTabIndex: tabParam,
              openCustomerConsult: openConsult,
              initialChatRoomId: roomId,
              initialCustomerHint: customerHint,
              navigationToken: requestToken,
            );
          },
          routes: [
            GoRoute(
              path: 'booking/:shopId',
              builder: (context, state) {
                final shopId = state.pathParameters['shopId'] ?? '';
                final barberId = state.uri.queryParameters['barberId'];
                return BookingFlowPage(
                  shopId: shopId,
                  preselectedBarberId: barberId,
                );
              },
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => const NotificationsPage(),
            ),
            GoRoute(
              path: 'my-bookings',
              builder: (context, state) => const MyBookingsPage(),
            ),
            GoRoute(
              path: 'register-shop',
              builder: (context, state) => const RegisterShopPage(),
            ),
            GoRoute(
              path: 'profile-social',
              builder: (context, state) {
                final targetUserId = state.uri.queryParameters['userId'];
                return ProfileSocialPage(targetUserId: targetUserId);
              },
            ),
            GoRoute(
              path: 'chat/:roomId',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId'] ?? '';
                return GroupChatPage(roomId: roomId);
              },
            ),
          ],
        ),
      ],
    );
  }
}
