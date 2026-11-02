import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _vndFormat = NumberFormat('#,###', 'vi_VN');

  static String formatVnd(int amount) {
    return '${_vndFormat.format(amount).replaceAll(',', '.')}đ';
  }

  static String formatDistanceKm(double km) {
    if (km < 1.0) {
      return 'Cách đây ${(km * 1000).round()}m';
    }
    return 'Cách đây ${km.toStringAsFixed(1)}km';
  }

  static int hhMmToMinutesFromMidnight(String hhMm) {
    final parts = hhMm.trim().split(':');
    if (parts.length < 2) return 8 * 60 + 30;
    final h = int.tryParse(parts[0]) ?? 8;
    final m = int.tryParse(parts[1]) ?? 30;
    return h * 60 + m;
  }

  static String minutesFromMidnightToHhMm(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDateDdMmYyyy(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return formatDateDdMmYyyy(time);
  }

  static String weekdayShortVi(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      default:
        return 'CN';
    }
  }
}

