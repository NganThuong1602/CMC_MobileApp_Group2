import '../../core/enums/app_enums.dart';
import '../../core/utils/result.dart';
import '../entities/booking_entity.dart';
import '../entities/payment_transaction_entity.dart';
import '../entities/time_slot_entity.dart';

class CreatedBookingBundle {
  final BookingEntity booking;
  final PaymentTransactionEntity? paymentQr;

  const CreatedBookingBundle({
    required this.booking,
    this.paymentQr,
  });
}

abstract class BookingRepository {
  Future<Result<DaySlotSchedule>> getDaySlotSchedule({
    required String shopId,
    required String barberId,
    required DateTime date,
    required int totalDurationMinutes,
    String? currentUserId,
  });

  Future<Result<CreatedBookingBundle>> createBooking({
    required String shopId,
    required String barberId,
    required String customerId,
    required List<String> serviceIds,
    required DateTime date,
    required int startMinutes,
    BookingShift? shift,
    required PaymentMethod paymentMethod,
  });

  Future<Result<List<BookingEntity>>> getCustomerBookings(String customerId);

  Future<Result<BookingEntity>> cancelBooking({
    required String bookingId,
    required String customerId,
  });

  Future<Result<BookingEntity>> confirmBookingPaidByBarber({
    required String bookingId,
    required String barberUserId,
  });
}

