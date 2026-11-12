import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/services/booking_slot_calculator.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/payment_transaction_entity.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/entities/time_slot_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/local/in_memory_database.dart';
import '../datasources/remote/remote_api_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final InMemoryDatabase db;
  final RemoteApiDataSource remote;
  final BookingSlotCalculator calculator;

  const BookingRepositoryImpl({
    required this.db,
    required this.remote,
    required this.calculator,
  });

  String _formatDateYyyyMmDd(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _extractDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.first.toString() : msg.toString();
    }
    return fallback;
  }

  List<TimeSlotEntity> _mapRemoteSlots(List<dynamic> rawList, bool isMorning) {
    final now = DateTime.now();
    return rawList.whereType<Map>().map((raw) {
      final m = Map<String, dynamic>.from(raw);
      final start = (m['startMinutes'] as num?)?.toInt() ?? 510;
      final end = (m['endMinutes'] as num?)?.toInt() ?? (start + 30);
      final isBooked = m['isBooked'] as bool? ?? false;
      final isOverflow = m['isOverflow'] as bool? ?? false;
      final isSelectable = m['isSelectable'] as bool? ?? (!isBooked && !isOverflow);
      return TimeSlotEntity(
        startMinutes: start,
        allocatedEndMinutes: end,
        isMorning: isMorning,
        isBooked: isBooked,
        hasDurationConflict: isOverflow || (!isSelectable && !isBooked && now.year > 0),
        unavailableReason: m['disabledReason']?.toString(),
      );
    }).toList();
  }

  ShiftOptionEntity? _mapRemoteShift(
    dynamic raw,
    BookingShift fallbackShift,
  ) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final parsedShift =
        BookingShift.fromApi(map['shift']?.toString()) ?? fallbackShift;
    return ShiftOptionEntity(
      shift: parsedShift,
      label: (map['label'] ?? parsedShift.label).toString(),
      shiftRangeLabel: (map['shiftRange'] ?? '').toString(),
      startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (map['endMinutes'] as num?)?.toInt() ?? 0,
      assignedRangeLabel: map['assignedRange']?.toString(),
      bookedCount: (map['bookedCount'] as num?)?.toInt() ?? 0,
      isAvailable: map['isAvailable'] == true,
      unavailableReason: map['disabledReason']?.toString(),
    );
  }

  @override
  Future<Result<DaySlotSchedule>> getDaySlotSchedule({
    required String shopId,
    required String barberId,
    required DateTime date,
    required int totalDurationMinutes,
    String? currentUserId,
  }) async {
    try {
      final map = await remote.getAvailableSlots(
        shopId: shopId,
        barberId: barberId,
        dateStr: _formatDateYyyyMmDd(date),
        durationMinutes: totalDurationMinutes,
      );
      final morningShift = _mapRemoteShift(
        map['morning'],
        BookingShift.morning,
      );
      final afternoonShift = _mapRemoteShift(
        map['afternoon'],
        BookingShift.afternoon,
      );
      final morning = _mapRemoteSlots(
        (map['morningSlots'] as List?) ?? const [],
        true,
      );
      final afternoon = _mapRemoteSlots(
        (map['afternoonSlots'] as List?) ?? const [],
        false,
      );
      return Result.success(
        DaySlotSchedule(
          date: date,
          totalDurationMinutes: totalDurationMinutes,
          morningSlots: morning,
          afternoonSlots: afternoon,
          morningShift: morningShift,
          afternoonShift: afternoonShift,
        ),
      );
    } catch (_) {}

    final shopIdx = db.shops.indexWhere((s) => s.id == shopId);
    if (shopIdx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy quán'));
    }
    final shop = db.shops[shopIdx];

    final barberBookings =
        db.bookings.where((b) => b.barberId == barberId).toList();
    final barberLocks =
        db.slotLocks.where((l) => l.barberId == barberId).toList();

    final schedule = calculator.buildDaySchedule(
      date: date,
      shopOpenTime: shop.openTime,
      shopCloseTime: shop.closeTime,
      totalDurationMinutes: totalDurationMinutes,
      existingBookings: barberBookings,
      activeLocks: barberLocks,
      now: DateTime.now(),
      currentUserId: currentUserId,
    );

    return Result.success(schedule);
  }

  @override
  Future<Result<CreatedBookingBundle>> createBooking({
    required String shopId,
    required String barberId,
    required String customerId,
    required List<String> serviceIds,
    required DateTime date,
    required int startMinutes,
    BookingShift? shift,
    required PaymentMethod paymentMethod,
  }) async {
    if (serviceIds.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng chọn ít nhất 1 dịch vụ'),
      );
    }

    final isQr = paymentMethod == PaymentMethod.qrCode;
    try {
      final createdRemote = await remote.createBooking(
        shopId: shopId,
        barberId: barberId,
        serviceIds: serviceIds,
        bookingDate: _formatDateYyyyMmDd(date),
        startMinutes: startMinutes,
        paymentMethod: isQr ? 'SEPAY_QR' : 'CASH_AT_SHOP',
        shift: shift?.apiValue,
      );
      db.bookings.removeWhere((b) => b.id == createdRemote.id);
      db.bookings.insert(0, createdRemote);

      PaymentTransactionEntity? paymentQr;
      if (isQr) {
        final qrTx = await remote.createBookingQr(createdRemote.id);
        paymentQr = qrTx;
        db.transactions.removeWhere((t) => t.paymentCode == qrTx.paymentCode);
        db.transactions.add(qrTx);
        db.pendingBookingIdByPaymentCode[qrTx.paymentCode] = createdRemote.id;
      }

      return Result.success(
        CreatedBookingBundle(booking: createdRemote, paymentQr: paymentQr),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(
            _extractDioError(
              e,
              'Khung giờ này bị tràn ca hoặc vừa có người đặt trước!',
            ),
          ),
        );
      }
    } catch (_) {}

    final shopIdx = db.shops.indexWhere((s) => s.id == shopId);
    final barberIdx = db.barbers.indexWhere((b) => b.id == barberId);
    final customerIdx = db.users.indexWhere((u) => u.id == customerId);
    if (shopIdx == -1 || barberIdx == -1 || customerIdx == -1) {
      return Result.failure(
        const ValidationFailure('Thông tin quán, thợ hoặc khách không hợp lệ'),
      );
    }

    final shop = db.shops[shopIdx];
    final barber = db.barbers[barberIdx];
    final customer = db.users[customerIdx];
    final selectedServices = db.services
        .where((s) => s.shopId == shopId && serviceIds.contains(s.id))
        .toList();

    final summary = calculator.calculateServicesSummary(
      selectedServices,
      discountPercent: shop.activeDiscountPercent,
    );
    final openMins = AppFormatters.hhMmToMinutesFromMidnight(shop.openTime);
    final closeMins = AppFormatters.hhMmToMinutesFromMidnight(shop.closeTime);
    var resolvedStart = startMinutes;
    final barberBookings =
        db.bookings.where((b) => b.barberId == barberId).toList();
    if (shift != null) {
      final dayBookings = barberBookings
          .where((b) => b.status != BookingStatus.cancelled && b.isSameDay(date))
          .toList();
      final shiftStart = shift == BookingShift.morning
          ? (openMins < AppConstants.morningShiftEndMinutes
              ? openMins
              : 8 * 60 + 30)
          : AppConstants.afternoonShiftStartMinutes;
      final shiftEnd = shift == BookingShift.morning
          ? AppConstants.morningShiftEndMinutes
          : (closeMins > AppConstants.afternoonShiftStartMinutes
              ? closeMins
              : 20 * 60 + 30);
      final option = calculator.computeShiftOption(
        shift: shift,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        durationMinutes: summary.totalDurationMinutes,
        dayBookings: dayBookings,
      );
      if (!option.isAvailable) {
        return Result.failure(
          ConflictFailure(
            option.unavailableReason ??
                'Ca này đã hết chỗ, vui lòng chọn ca khác!',
          ),
        );
      }
      resolvedStart = option.startMinutes;
    }
    final endMinutes = resolvedStart + summary.totalDurationMinutes;

    final barberLocks =
        db.slotLocks.where((l) => l.barberId == barberId).toList();

    final conflict = calculator.hasConflict(
      date: date,
      startMinutes: resolvedStart,
      endMinutes: endMinutes,
      shopOpenMinutes: openMins,
      shopCloseMinutes: closeMins,
      existingBookings: barberBookings,
      activeLocks: barberLocks,
      now: DateTime.now(),
      ignoreUserId: customerId,
    );

    if (conflict) {
      return Result.failure(
        const ConflictFailure(
          'Khung giờ này bị tràn ca hoặc vừa có người đặt trước. Vui lòng chọn ca khác!',
        ),
      );
    }

    final codeDigits =
        (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
    final paymentCode = isQr ? 'PAYBOOKING$codeDigits' : null;
    final bookingId = 'bk_${DateTime.now().millisecondsSinceEpoch}';

    final booking = BookingEntity(
      id: bookingId,
      shopId: shop.id,
      shopName: shop.name,
      barberId: barber.id,
      barberName: barber.fullName,
      customerId: customer.id,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      services: selectedServices,
      date: DateTime(date.year, date.month, date.day),
      startMinutes: resolvedStart,
      endMinutes: endMinutes,
      totalPrice: summary.totalPrice,
      totalDurationMinutes: summary.totalDurationMinutes,
      paymentMethod: paymentMethod,
      status: isQr ? BookingStatus.pending : BookingStatus.confirmed,
      isPaid: false,
      paymentCode: paymentCode,
      createdAt: DateTime.now(),
      shift: shift,
    );

    db.bookings.insert(0, booking);

    PaymentTransactionEntity? paymentQr;
    if (isQr && paymentCode != null) {
      final transferContent = 'PAY BOOKING $codeDigits';
      paymentQr = PaymentTransactionEntity(
        id: 'tx_$codeDigits',
        userId: customer.id,
        type: 'BOOKING_PAYMENT',
        amount: summary.totalPrice,
        paymentCode: paymentCode,
        transferContent: transferContent,
        qrImageUrl: db.buildVietQrUrl(
          amount: summary.totalPrice,
          transferContent: transferContent,
        ),
        status: 'PENDING',
        referenceId: bookingId,
      );
      db.transactions.add(paymentQr);
      db.pendingBookingIdByPaymentCode[paymentCode] = bookingId;
    }

    final timeStr = AppFormatters.minutesFromMidnightToHhMm(startMinutes);
    db.notifications.insertAll(0, [
      AppNotificationEntity(
        id: 'notif_mgr_${DateTime.now().microsecondsSinceEpoch}',
        userId: shop.ownerId,
        title: 'Lịch đặt mới tại ${shop.name}',
        body:
            '${customer.fullName} đã đặt lịch lúc $timeStr với Barber ${barber.fullName}.',
        type: NotificationType.bookingCreated,
        targetShopId: shop.id,
        createdAt: DateTime.now(),
      ),
      AppNotificationEntity(
        id: 'notif_brb_${DateTime.now().microsecondsSinceEpoch}',
        userId: barber.userId,
        title: 'Khách đặt lịch lúc $timeStr',
        body:
            'Khách ${customer.fullName} (${customer.phone}) đặt ${summary.totalDurationMinutes} phút.',
        type: NotificationType.bookingCreated,
        targetShopId: shop.id,
        createdAt: DateTime.now(),
      ),
    ]);

    return Result.success(
      CreatedBookingBundle(booking: booking, paymentQr: paymentQr),
    );
  }

  @override
  Future<Result<List<BookingEntity>>> getCustomerBookings(
    String customerId,
  ) async {
    try {
      final remoteList = await remote.getMyBookings();
      for (final b in remoteList) {
        final idx = db.bookings.indexWhere((x) => x.id == b.id);
        if (idx == -1) {
          db.bookings.add(b);
        } else {
          db.bookings[idx] = b;
        }
      }
      return Result.success(remoteList);
    } catch (_) {}

    final list =
        db.bookings.where((b) => b.customerId == customerId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Result.success(list);
  }

  @override
  Future<Result<BookingEntity>> cancelBooking({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      final cancelledRemote = await remote.cancelBooking(bookingId);
      final idx = db.bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) db.bookings[idx] = cancelledRemote;
      return Result.success(cancelledRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(_extractDioError(e, 'Không thể hủy lịch hẹn này')),
        );
      }
    } catch (_) {}

    final idx = db.bookings.indexWhere(
      (b) => b.id == bookingId && b.customerId == customerId,
    );
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy lịch hẹn'));
    }
    final current = db.bookings[idx];
    if (!current.canCancel) {
      return Result.failure(
        const ConflictFailure('Không thể hủy lịch đã hoàn thành hoặc đã hủy'),
      );
    }
    final cancelled = current.copyWith(status: BookingStatus.cancelled);
    db.bookings[idx] = cancelled;
    return Result.success(cancelled);
  }

  @override
  Future<Result<BookingEntity>> confirmBookingPaidByBarber({
    required String bookingId,
    required String barberUserId,
  }) async {
    try {
      final completedRemote = await remote.confirmBookingPaid(bookingId);
      final idx = db.bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) db.bookings[idx] = completedRemote;
      return Result.success(completedRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(
            _extractDioError(e, 'Không thể xác nhận thanh toán lịch hẹn'),
          ),
        );
      }
    } catch (_) {}

    final idx = db.bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy lịch hẹn'));
    }
    final current = db.bookings[idx];
    if (current.status == BookingStatus.cancelled) {
      return Result.failure(
        const ConflictFailure('Lịch hẹn này đã bị hủy trước đó'),
      );
    }

    final completed = current.copyWith(
      status: BookingStatus.completed,
      isPaid: true,
    );
    db.bookings[idx] = completed;

    db.notifications.insert(
      0,
      AppNotificationEntity(
        id: 'notif_paid_${DateTime.now().millisecondsSinceEpoch}',
        userId: completed.customerId,
        title: 'Hoàn tất dịch vụ & thanh toán',
        body:
            'Barber ${completed.barberName} đã xác nhận thanh toán ${AppFormatters.formatVnd(completed.totalPrice)}. Cảm ơn bạn!',
        type: NotificationType.paymentConfirmed,
        targetShopId: completed.shopId,
        createdAt: DateTime.now(),
      ),
    );

    return Result.success(completed);
  }
}
