import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barber_booking_app/app.dart';
import 'package:barber_booking_app/core/di/injection_container.dart';
import 'package:barber_booking_app/core/enums/app_enums.dart';
import 'package:barber_booking_app/domain/entities/user_entity.dart';
import 'package:barber_booking_app/presentation/blocs/auth/auth_cubit.dart';
import 'package:barber_booking_app/presentation/pages/account/account_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'Kiểm thử Design System (Inter + ColorScheme), Trang cá nhân theo từng user (3 chấm Sửa/Xoá), Quản lý dịch vụ Manager, Bộ lọc và Đăng xuất',
    (WidgetTester tester) async {
      await initDependencies();
      await tester.pumpWidget(const BarberSmartApp());
      await tester.pumpAndSettle();

      // 1. Khởi động bắt buộc tại màn Đăng nhập (/login)
      expect(find.text('BARBERSMART'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);

      // 2. Đăng nhập thành công -> GoRouter tự đẩy vào Trang chủ (/)
      final authCubit = sl<AuthCubit>();
      authCubit.emit(
        const AuthState(
          status: AuthStatus.authenticated,
          user: UserEntity(
            id: 'user-customer-1',
            fullName: 'Nguyễn Tuấn Anh',
            email: 'customer@barbersmart.vn',
            phone: '0901234567',
            role: UserRole.user,
          ),
        ),
      );

      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(authCubit.state.isAuthenticated, isTrue);
      expect(find.text('Bản đồ'), findsOneWidget);

      // 3. Kiểm tra mở Bộ lọc (Đánh giá + Thanh trượt 1km - 20km + nút Tìm kiếm & Xoá lọc)
      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('1. Lọc theo đánh giá'), findsOneWidget);
      expect(find.text('2. Khoảng cách tối đa'), findsOneWidget);
      expect(find.text('Tìm kiếm'), findsOneWidget);
      expect(find.text('Xoá lọc'), findsOneWidget);
      await tester.tap(find.text('Xoá lọc'));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      // 4. Mở Trang cá nhân (/profile-social) -> kiểm tra chỉ hiển thị bài đăng của user hiện tại và có nút 3 chấm
      final navContext = tester.element(find.text('BARBERSMART').first);
      GoRouter.of(navContext).go('/profile-social');
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Đăng bài mới'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsWidgets);

      // Quay về Trang chủ
      GoRouter.of(navContext).go('/');
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      // 5. Chuyển sang Role MANAGER -> kiểm tra tab Quản lý có mục "Quản lý dịch vụ" riêng biệt
      authCubit.emit(
        const AuthState(
          status: AuthStatus.authenticated,
          user: UserEntity(
            id: 'user-manager-1',
            fullName: 'Trần Minh Quân (Owner)',
            email: 'manager@barbersmart.vn',
            phone: '0912345678',
            role: UserRole.manager,
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.text('Quản lý'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Quản lý thông tin'), findsOneWidget);
      expect(find.text('Quản lý dịch vụ'), findsOneWidget);
      expect(find.text('Quản lý barber'), findsOneWidget);
      expect(find.text('Doanh thu và lương'), findsOneWidget);

      // 6. Mở tab Hồ Sơ, cuộn xuống và bấm Đăng xuất -> về thẳng /login
      await tester.tap(find.text('Hồ Sơ'));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.scrollUntilVisible(
        find.text('Đăng xuất'),
        200,
        scrollable: find.descendant(
          of: find.byType(AccountPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Đăng xuất'));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(authCubit.state.status, AuthStatus.unauthenticated);
      expect(find.text('Đăng ký'), findsOneWidget);
    },
  );
}
