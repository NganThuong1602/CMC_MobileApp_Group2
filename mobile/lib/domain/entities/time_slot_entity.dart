import 'package:equatable/equatable.dart';
import '../../core/utils/formatters.dart';

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
  final List<TimeSlotEntity> morningSlots;
  final List<TimeSlotEntity> afternoonSlots;

  const DaySlotSchedule({
    required this.date,
    required this.totalDurationMinutes,
    required this.morningSlots,
    required this.afternoonSlots,
  });

  @override
  List<Object?> get props => [
        date,
        totalDurationMinutes,
        morningSlots,
        afternoonSlots,
      ];
}

