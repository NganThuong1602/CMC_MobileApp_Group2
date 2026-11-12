import 'package:equatable/equatable.dart';
import '../../core/enums/app_enums.dart';
import '../../core/utils/formatters.dart';

class ShiftOptionEntity extends Equatable {
  final BookingShift shift;
  final String label;
  final String shiftRangeLabel;
  final int startMinutes;
  final int endMinutes;
  final String? assignedRangeLabel;
  final int bookedCount;
  final bool isAvailable;
  final String? unavailableReason;

  const ShiftOptionEntity({
    required this.shift,
    required this.label,
    required this.shiftRangeLabel,
    required this.startMinutes,
    required this.endMinutes,
    this.assignedRangeLabel,
    this.bookedCount = 0,
    this.isAvailable = true,
    this.unavailableReason,
  });

  @override
  List<Object?> get props => [
        shift,
        label,
        shiftRangeLabel,
        startMinutes,
        endMinutes,
        assignedRangeLabel,
        bookedCount,
        isAvailable,
        unavailableReason,
      ];
}

class TimeSlotEntity extends Equatable {
  final int startMinutes;
  final int allocatedEndMinutes;
  final bool isMorning;
  final bool isBooked;
  final bool hasDurationConflict;
  final String? unavailableReason;

  const TimeSlotEntity({
    required this.startMinutes,
    required this.allocatedEndMinutes,
    required this.isMorning,
    required this.isBooked,
    required this.hasDurationConflict,
    this.unavailableReason,
  });

  bool get isSelectable => !isBooked && !hasDurationConflict;

  String get timeLabel => AppFormatters.minutesFromMidnightToHhMm(startMinutes);

  String get allocatedRangeLabel =>
      '${AppFormatters.minutesFromMidnightToHhMm(startMinutes)} - ${AppFormatters.minutesFromMidnightToHhMm(allocatedEndMinutes)}';

  @override
  List<Object?> get props => [
        startMinutes,
        allocatedEndMinutes,
        isMorning,
        isBooked,
        hasDurationConflict,
        unavailableReason,
      ];
}

class SlotLockEntity extends Equatable {
  final String id;
  final String barberId;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final String lockedByUserId;
  final DateTime expiresAt;

  const SlotLockEntity({
    required this.id,
    required this.barberId,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.lockedByUserId,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  @override
  List<Object?> get props => [
        id,
        barberId,
        date,
        startMinutes,
        endMinutes,
        lockedByUserId,
        expiresAt,
      ];
}

class DaySlotSchedule extends Equatable {
  final DateTime date;
  final int totalDurationMinutes;
  final ShiftOptionEntity? morningShift;
  final ShiftOptionEntity? afternoonShift;
  final List<TimeSlotEntity> morningSlots;
  final List<TimeSlotEntity> afternoonSlots;

  const DaySlotSchedule({
    required this.date,
    required this.totalDurationMinutes,
    this.morningShift,
    this.afternoonShift,
    this.morningSlots = const [],
    this.afternoonSlots = const [],
  });

  @override
  List<Object?> get props => [
        date,
        totalDurationMinutes,
        morningShift,
        afternoonShift,
        morningSlots,
        afternoonSlots,
      ];
}

