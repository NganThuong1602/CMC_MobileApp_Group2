import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:barber_booking_app/app.dart';
import 'package:barber_booking_app/core/di/injection_container.dart';
import 'package:barber_booking_app/core/enums/app_enums.dart';
import 'package:barber_booking_app/domain/entities/user_entity.dart';
import 'package:barber_booking_app/presentation/blocs/auth/auth_cubit.dart';
import 'package:barber_booking_app/presentation/pages/account/account_page.dart';

void main() {
  testWidgets(
    'Kiểm thử luồng Đăng nhập, Lọc (Đánh giá + Khoảng cách 1-20km), Xoá lọc khi đổi tab Map/Home, Nút Back sau thanh toán (/my-bookings) và Đăng xuất',
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
            id: 'test-user-001',
            fullName: 'Khách Kiểm Thử',
            email: 'test@barbersmart.vn',
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

      // 4. Chuyển sang Bản đồ, gõ tìm "liem", sau đó bấm về Trang chủ -> phải tự xoá filter
      await tester.tap(find.text('Bản đồ'));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final mapSearchField = find.widgetWithText(
        TextField,
        'Tìm quán trên bản đồ...',
      );
      expect(mapSearchField, findsOneWidget);
      await tester.enterText(mapSearchField, 'liem');
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.tap(find.text('Trang chủ'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final TextField clearedMapField = tester.widget(
        find.widgetWithText(TextField, 'Tìm quán trên bản đồ...').evaluate().isNotEmpty
            ? find.widgetWithText(TextField, 'Tìm quán trên bản đồ...')
            : find.byType(TextField).first,
      );
      expect(clearedMapField.controller?.text ?? '', isEmpty);

      // 5. Giả lập sau khi thanh toán gọi context.go('/my-bookings') -> phải có nút Back quay về Home
      final navContext = tester.element(find.text('BARBERSMART').first);
      GoRouter.of(navContext).go('/my-bookings');
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Lịch đã đặt'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Hồ Sơ'), findsOneWidget);

      // 6. Mở tab Hồ Sơ, cuộn xuống và bấm Đăng xuất -> về thẳng /login không trắng màn hình
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
