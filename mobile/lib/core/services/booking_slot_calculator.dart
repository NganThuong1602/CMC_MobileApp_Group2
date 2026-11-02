import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/time_slot_entity.dart';
import '../constants/app_constants.dart';
import '../enums/app_enums.dart';
import '../utils/formatters.dart';

class BookingCalculationSummary extends Equatable {
  final int totalPrice;
  final int totalDurationMinutes;
  final int serviceCount;

  const BookingCalculationSummary({
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.serviceCount,
  });

  @override
  List<Object?> get props => [totalPrice, totalDurationMinutes, serviceCount];
}

/// Core Booking Engine chuẩn theo đặc tả Fullstack & Clarification A2:
/// - Bước nhảy 15 phút (08:30, 08:45, 09:00...).
/// - 2 hàng ngang liên tục:
///   + Ca sáng: từ giờ mở cửa quán -> 11:30 (nghỉ trưa 11:30 - 14:00).
///   + Ca chiều: từ 14:00 -> giờ đóng cửa quán.
/// - Logic Chặn tràn giờ: Nếu [start + totalDuration] vượt quá 11:30 (ca sáng)
///   hoặc vượt quá giờ đóng cửa (ca chiều), mốc đó bị Disable (Khoá) ngay từ đầu!
/// - Mốc giờ đã có khách đặt hoặc bị chồng lấn chuyển màu xám.
class BookingSlotCalculator {
  const BookingSlotCalculator();

  BookingCalculationSummary calculateServicesSummary(
    List<ServiceEntity> selectedServices,
  ) {
    final totalPrice = selectedServices.fold<int>(
      0,
      (sum, item) => sum + item.price,
    );
    final totalDuration = selectedServices.fold<int>(
      0,
      (sum, item) => sum + item.durationMinutes,
    );
    return BookingCalculationSummary(
      totalPrice: totalPrice,
      totalDurationMinutes: totalDuration,
      serviceCount: selectedServices.length,
    );
  }

  bool isOverlapping({
    required int startA,
    required int endA,
    required int startB,
    required int endB,
  }) {
    return startA < endB && endA > startB;
  }

  bool hasConflict({
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
    required int shopOpenMinutes,
    required int shopCloseMinutes,
    required List<BookingEntity> existingBookings,
    required List<SlotLockEntity> activeLocks,
    required DateTime now,
    String? ignoreUserId,
  }) {
    final inMorningShift = startMinutes >= shopOpenMinutes &&
        endMinutes <= AppConstants.lunchStartMinutes;
    final inAfternoonShift = startMinutes >= AppConstants.lunchEndMinutes &&
        endMinutes <= shopCloseMinutes;

    // Chặn tràn qua 11:30 (nghỉ trưa) hoặc giờ đóng cửa
    if (!inMorningShift && !inAfternoonShift) {
      return true;
    }

    for (final booking in existingBookings) {
      if (booking.status == BookingStatus.cancelled) continue;
      if (!booking.isSameDay(date)) continue;
      if (isOverlapping(
        startA: startMinutes,
        endA: endMinutes,
        startB: booking.startMinutes,
        endB: booking.endMinutes,
      )) {
        return true;
      }
    }

    for (final lock in activeLocks) {
      if (lock.isExpiredAt(now)) continue;
      if (!lock.isSameDay(date)) continue;
      if (ignoreUserId != null && lock.lockedByUserId == ignoreUserId) {
        continue;
      }
      if (isOverlapping(
        startA: startMinutes,
        endA: endMinutes,
        startB: lock.startMinutes,
        endB: lock.endMinutes,
      )) {
        return true;
      }
    }

    return false;
  }

  DaySlotSchedule buildDaySchedule({
    required DateTime date,
    required String shopOpenTime,
    required String shopCloseTime,
    required int totalDurationMinutes,
    required List<BookingEntity> existingBookings,
    required List<SlotLockEntity> activeLocks,
    required DateTime now,
    String? currentUserId,
    int stepMinutes = AppConstants.slotIntervalMinutes,
  }) {
    final openMinutes = AppFormatters.hhMmToMinutesFromMidnight(shopOpenTime);
    final closeMinutes = AppFormatters.hhMmToMinutesFromMidnight(shopCloseTime);
    final effectiveDuration =
        totalDurationMinutes > 0 ? totalDurationMinutes : stepMinutes;

    final validBookings = existingBookings
        .where((b) => b.status != BookingStatus.cancelled && b.isSameDay(date))
        .toList();

    final validLocks = activeLocks
        .where(
          (l) =>
              !l.isExpiredAt(now) &&
              l.isSameDay(date) &&
              (currentUserId == null || l.lockedByUserId != currentUserId),
        )
        .toList();

    List<TimeSlotEntity> buildShift({
      required int shiftStart,
      required int shiftEnd,
      required bool isMorning,
      required String shiftLimitLabel,
    }) {
      final list = <TimeSlotEntity>[];
      for (int start = shiftStart; start < shiftEnd; start += stepMinutes) {
        final allocatedEnd = start + effectiveDuration;

        final directlyBooked = validBookings.any(
              (b) => start >= b.startMinutes && start < b.endMinutes,
            ) ||
            validLocks.any(
              (l) => start >= l.startMinutes && start < l.endMinutes,
            );

        bool hasDurationConflict = false;
        String? reason;

        if (directlyBooked) {
          reason = 'Khung giờ đã có khách đặt';
        } else if (allocatedEnd > shiftEnd) {
          // Chặn tràn giờ qua 11:30 hoặc giờ đóng cửa
          hasDurationConflict = true;
          reason = 'Lấn qua $shiftLimitLabel (${AppFormatters.minutesFromMidnightToHhMm(shiftEnd)})';
        } else {
          final overlapsNext = validBookings.any(
                (b) => isOverlapping(
                  startA: start,
                  endA: allocatedEnd,
                  startB: b.startMinutes,
                  endB: b.endMinutes,
                ),
              ) ||
              validLocks.any(
                (l) => isOverlapping(
                  startA: start,
                  endA: allocatedEnd,
                  startB: l.startMinutes,
                  endB: l.endMinutes,
                ),
              );

          if (overlapsNext) {
            hasDurationConflict = true;
            reason =
                'Không đủ $effectiveDuration phút trống trước lịch kế tiếp';
          }
        }

        list.add(
          TimeSlotEntity(
            startMinutes: start,
            allocatedEndMinutes: allocatedEnd,
            isMorning: isMorning,
            isBooked: directlyBooked,
            hasDurationConflict: hasDurationConflict,
            unavailableReason: reason,
          ),
        );
      }
      return list;
    }

    final morningStart = openMinutes < AppConstants.lunchStartMinutes
        ? openMinutes
        : 8 * 60 + 30;
    final afternoonEnd = closeMinutes > AppConstants.lunchEndMinutes
        ? closeMinutes
        : 20 * 60 + 30;

    final morningSlots = buildShift(
      shiftStart: morningStart,
      shiftEnd: AppConstants.lunchStartMinutes,
      isMorning: true,
      shiftLimitLabel: 'ca sáng',
    );

    final afternoonSlots = buildShift(
      shiftStart: AppConstants.lunchEndMinutes,
      shiftEnd: afternoonEnd,
      isMorning: false,
      shiftLimitLabel: 'giờ đóng cửa',
    );

    return DaySlotSchedule(
      date: DateTime(date.year, date.month, date.day),
      totalDurationMinutes: effectiveDuration,
      morningSlots: morningSlots,
      afternoonSlots: afternoonSlots,
    );
  }
}

