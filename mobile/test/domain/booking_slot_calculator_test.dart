import 'package:flutter_test/flutter_test.dart';
import 'package:barber_booking_app/core/enums/app_enums.dart';
import 'package:barber_booking_app/core/services/booking_slot_calculator.dart';
import 'package:barber_booking_app/domain/entities/booking_entity.dart';
import 'package:barber_booking_app/domain/entities/service_entity.dart';

void main() {
  const calculator = BookingSlotCalculator();
  final testDate = DateTime(2026, 11, 5);

  test(
    'Bước nhảy 15 phút & Chặn tràn giờ qua 11:30 (ca sáng) / 20:30 (ca chiều)',
    () {
      const services = [
        ServiceEntity(
          id: 's1',
          shopId: 'shop_1',
          name: 'Cắt tạo kiểu',
          price: 100000,
          durationMinutes: 30,
        ),
        ServiceEntity(
          id: 's2',
          shopId: 'shop_1',
          name: 'Gội đầu dưỡng sinh',
          price: 70000,
          durationMinutes: 20,
        ),
      ];
      final summary = calculator.calculateServicesSummary(services);
      expect(summary.totalDurationMinutes, 50);
      expect(summary.totalPrice, 170000);

      final schedule = calculator.buildDaySchedule(
        date: testDate,
        shopOpenTime: '08:30',
        shopCloseTime: '20:30',
        totalDurationMinutes: summary.totalDurationMinutes,
        existingBookings: const [],
        activeLocks: const [],
        now: DateTime(2026, 11, 5, 8, 0),
      );

      // Mốc 10:30 + 50p = 11:20 (<= 11:30) -> Cho phép chọn
      final slot1030 = schedule.morningSlots
          .firstWhere((s) => s.timeLabel == '10:30');
      expect(slot1030.isSelectable, isTrue);

      // Mốc 10:45 + 50p = 11:35 (> 11:30) -> Bắt buộc Disable khóa ngay từ đầu!
      final slot1045 = schedule.morningSlots
          .firstWhere((s) => s.timeLabel == '10:45');
      expect(slot1045.hasDurationConflict, isTrue);
      expect(slot1045.isSelectable, isFalse);

      // Mốc 19:45 + 50p = 20:35 (> 20:30) -> Bắt buộc Disable khóa ngay từ đầu!
      final slot1945 = schedule.afternoonSlots
          .firstWhere((s) => s.timeLabel == '19:45');
      expect(slot1945.hasDurationConflict, isTrue);
      expect(slot1945.isSelectable, isFalse);
    },
  );

  test(
    'Khóa các mốc giờ bị chồng lấn với lịch đã đặt trước',
    () {
      final existing = [
        BookingEntity(
          id: 'b1',
          shopId: 'shop_1',
          shopName: 'Vũ Trí Barber',
          barberId: 'barber_1',
          barberName: 'Lê Hoàng Phúc',
          customerId: 'u1',
          customerName: 'Nguyễn Tuấn Anh',
          customerPhone: '0908123456',
          services: const [],
          date: testDate,
          startMinutes: 9 * 60, // 09:00
          endMinutes: 9 * 60 + 45, // 09:45
          totalPrice: 120000,
          totalDurationMinutes: 45,
          paymentMethod: PaymentMethod.atShop,
          status: BookingStatus.confirmed,
          isPaid: false,
          createdAt: testDate,
        ),
      ];

      final schedule = calculator.buildDaySchedule(
        date: testDate,
        shopOpenTime: '08:30',
        shopCloseTime: '20:30',
        totalDurationMinutes: 45,
        existingBookings: existing,
        activeLocks: const [],
        now: DateTime(2026, 11, 5, 8, 0),
      );

      // 08:30 + 45p = 09:15 (đè lên 09:00) -> khóa tràn lịch
      final slot0830 = schedule.morningSlots
          .firstWhere((s) => s.timeLabel == '08:30');
      expect(slot0830.isSelectable, isFalse);

      // 09:00 đang có khách -> isBooked = true (xám)
      final slot0900 = schedule.morningSlots
          .firstWhere((s) => s.timeLabel == '09:00');
      expect(slot0900.isBooked, isTrue);

      // 09:45 trống hoàn toàn -> cho phép chọn
      final slot0945 = schedule.morningSlots
          .firstWhere((s) => s.timeLabel == '09:45');
      expect(slot0945.isSelectable, isTrue);
    },
  );
}

