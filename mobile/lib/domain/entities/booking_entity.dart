import 'package:equatable/equatable.dart';
import '../../core/enums/app_enums.dart';
import '../../core/utils/formatters.dart';
import 'service_entity.dart';

class BookingEntity extends Equatable {
  final String id;
  final String shopId;
  final String shopName;
  final String barberId;
  final String barberName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<ServiceEntity> services;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final int totalPrice;
  final int totalDurationMinutes;
  final PaymentMethod paymentMethod;
  final BookingStatus status;
  final bool isPaid;
  final String? paymentCode;
  final DateTime createdAt;

  const BookingEntity({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.barberId,
    required this.barberName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.services,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.paymentMethod,
    required this.status,
    required this.isPaid,
    this.paymentCode,
    required this.createdAt,
  });

  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  bool get canCancel =>
      status != BookingStatus.completed && status != BookingStatus.cancelled;

  String get timeRangeLabel =>
      '${AppFormatters.minutesFromMidnightToHhMm(startMinutes)} - ${AppFormatters.minutesFromMidnightToHhMm(endMinutes)}';

  BookingEntity copyWith({
    BookingStatus? status,
    bool? isPaid,
  }) {
    return BookingEntity(
      id: id,
      shopId: shopId,
      shopName: shopName,
      barberId: barberId,
      barberName: barberName,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      services: services,
      date: date,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      totalPrice: totalPrice,
      totalDurationMinutes: totalDurationMinutes,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      paymentCode: paymentCode,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        barberId,
        customerId,
        date,
        startMinutes,
        endMinutes,
        totalPrice,
        paymentMethod,
        status,
        isPaid,
        paymentCode,
      ];
}

