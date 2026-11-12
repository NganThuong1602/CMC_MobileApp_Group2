import '../../core/enums/app_enums.dart';
import '../../core/utils/result.dart';
import '../entities/booking_entity.dart';
import '../entities/time_slot_entity.dart';
import '../repositories/booking_repository.dart';

class GetDaySlotScheduleUseCase {
  final BookingRepository repository;
  const GetDaySlotScheduleUseCase(this.repository);

  Future<Result<DaySlotSchedule>> call({
    required String shopId,
    required String barberId,
    required DateTime date,
    required int totalDurationMinutes,
    String? currentUserId,
  }) {
    return repository.getDaySlotSchedule(
      shopId: shopId,
      barberId: barberId,
      date: date,
      totalDurationMinutes: totalDurationMinutes,
      currentUserId: currentUserId,
    );
  }
}

class CreateBookingUseCase {
  final BookingRepository repository;
  const CreateBookingUseCase(this.repository);

  Future<Result<CreatedBookingBundle>> call({
    required String shopId,
    required String barberId,
    required String customerId,
    required List<String> serviceIds,
    required DateTime date,
    required int startMinutes,
    BookingShift? shift,
    required PaymentMethod paymentMethod,
  }) {
    return repository.createBooking(
      shopId: shopId,
      barberId: barberId,
      customerId: customerId,
      serviceIds: serviceIds,
      date: date,
      startMinutes: startMinutes,
      shift: shift,
      paymentMethod: paymentMethod,
    );
  }
}

class CancelBookingUseCase {
  final BookingRepository repository;
  const CancelBookingUseCase(this.repository);

  Future<Result<BookingEntity>> call({
    required String bookingId,
    required String customerId,
  }) {
    return repository.cancelBooking(
      bookingId: bookingId,
      customerId: customerId,
    );
  }
}

