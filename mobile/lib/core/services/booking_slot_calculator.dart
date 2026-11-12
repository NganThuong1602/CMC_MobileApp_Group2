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
    List<ServiceEntity> selectedServices, {
    int discountPercent = 0,
  }) {
    final rawTotal = selectedServices.fold<int>(
      0,
      (sum, item) => sum + item.price,
    );
    final totalPrice = discountPercent > 0
        ? ((rawTotal * (100 - discountPercent)) / 100).round().clamp(0, rawTotal)
        : rawTotal;
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
        endMinutes <= AppConstants.morningShiftEndMinutes;
    final inAfternoonShift = startMinutes >= AppConstants.afternoonShiftStartMinutes &&
        endMinutes <= shopCloseMinutes;

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

    return false;
  }

  ShiftOptionEntity computeShiftOption({
    required BookingShift shift,
    required int shiftStart,
    required int shiftEnd,
    required int durationMinutes,
    required List<BookingEntity> dayBookings,
  }) {
    final shiftBookings = dayBookings.where((b) {
      if (b.shift != null) return b.shift == shift;
      return shift == BookingShift.morning
          ? b.endMinutes <= AppConstants.morningShiftEndMinutes
          : b.startMinutes >= AppConstants.afternoonShiftStartMinutes;
    }).toList();

    final maxEnd = shiftBookings.isEmpty
        ? null
        : shiftBookings
            .map((b) => b.endMinutes)
            .reduce((a, b) => a > b ? a : b);

    final startMinutes = maxEnd == null
        ? shiftStart
        : (shiftStart > maxEnd + AppConstants.bookingGapMinutes
            ? shiftStart
            : maxEnd + AppConstants.bookingGapMinutes);
    final endMinutes = startMinutes + durationMinutes;
    final isAvailable =
        shiftStart < shiftEnd && durationMinutes > 0 && endMinutes <= shiftEnd;

    final startStr = AppFormatters.minutesFromMidnightToHhMm(startMinutes);
    final endStr = AppFormatters.minutesFromMidnightToHhMm(endMinutes);
    final shiftRange =
        '${AppFormatters.minutesFromMidnightToHhMm(shiftStart)} - ${AppFormatters.minutesFromMidnightToHhMm(shiftEnd)}';

    return ShiftOptionEntity(
      shift: shift,
      label: shift.label,
      shiftRangeLabel: shiftRange,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      assignedRangeLabel: isAvailable ? '$startStr - $endStr' : null,
      bookedCount: shiftBookings.length,
      isAvailable: isAvailable,
      unavailableReason: isAvailable
          ? null
          : 'Ca này đã đầy lịch hoặc không còn đủ $durationMinutes phút trước ${AppFormatters.minutesFromMidnightToHhMm(shiftEnd)}',
    );
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
    final effectiveDuration = totalDurationMinutes > 0 ? totalDurationMinutes : 15;

    final validBookings = existingBookings
        .where((b) => b.status != BookingStatus.cancelled && b.isSameDay(date))
        .toList();

    final morningStart = openMinutes < AppConstants.morningShiftEndMinutes
        ? openMinutes
        : 8 * 60 + 30;
    final afternoonEnd = closeMinutes > AppConstants.afternoonShiftStartMinutes
        ? closeMinutes
        : 20 * 60 + 30;

    final morningShift = computeShiftOption(
      shift: BookingShift.morning,
      shiftStart: morningStart,
      shiftEnd: AppConstants.morningShiftEndMinutes,
      durationMinutes: effectiveDuration,
      dayBookings: validBookings,
    );

    final afternoonShift = computeShiftOption(
      shift: BookingShift.afternoon,
      shiftStart: AppConstants.afternoonShiftStartMinutes,
      shiftEnd: afternoonEnd,
      durationMinutes: effectiveDuration,
      dayBookings: validBookings,
    );

    return DaySlotSchedule(
      date: DateTime(date.year, date.month, date.day),
      totalDurationMinutes: effectiveDuration,
      morningShift: morningShift,
      afternoonShift: afternoonShift,
    );
  }
}

