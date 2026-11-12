import '../../core/utils/result.dart';
import '../entities/booking_entity.dart';
import '../entities/finance_entities.dart';
import '../repositories/barber_repository.dart';
import '../repositories/booking_repository.dart';

class ConfirmBookingPaidByBarberUseCase {
  final BookingRepository bookingRepository;
  const ConfirmBookingPaidByBarberUseCase(this.bookingRepository);

  Future<Result<BookingEntity>> call({
    required String bookingId,
    required String barberUserId,
  }) {
    return bookingRepository.confirmBookingPaidByBarber(
      bookingId: bookingId,
      barberUserId: barberUserId,
    );
  }
}

class GetBarberIncomeSummaryUseCase {
  final BarberRepository barberRepository;
  const GetBarberIncomeSummaryUseCase(this.barberRepository);

  Future<Result<BarberIncomeSummary>> call(String barberId) {
    return barberRepository.getBarberIncomeSummary(barberId);
  }
}

