import '../../core/utils/result.dart';
import '../entities/barber_entity.dart';
import '../entities/booking_entity.dart';
import '../entities/finance_entities.dart';
import '../entities/user_entity.dart';

abstract class BarberRepository {
  Future<Result<BarberEntity?>> getBarberByUserId(String userId);

  Future<Result<UserEntity>> searchUserForInvite(String emailOrPhone);

  Future<Result<void>> inviteBarberToShop({
    required String managerId,
    required String shopId,
    required String emailOrPhone,
    required int baseSalary,
  });

  Future<Result<UserEntity>> respondBarberInvitation({
    required String notificationId,
    required String userId,
    required bool accept,
  });

  Future<Result<BarberEntity>> updateBarberBaseSalary({
    required String barberId,
    required int baseSalary,
  });

  Future<Result<List<MonthlyBookingHeatDay>>> getMonthlyHeatmap({
    required String barberId,
    required int year,
    required int month,
  });

  Future<Result<List<BookingEntity>>> getBarberDayBookings({
    required String barberId,
    required DateTime date,
  });

  Future<Result<BarberIncomeSummary>> getBarberIncomeSummary(String barberId);
}

