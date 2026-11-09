import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/barber_entity.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/finance_entities.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/barber_repository.dart';
import '../datasources/local/in_memory_database.dart';
import '../datasources/remote/remote_api_datasource.dart';
import '../models/app_models.dart';

class BarberRepositoryImpl implements BarberRepository {
  final InMemoryDatabase db;
  final RemoteApiDataSource remote;

  const BarberRepositoryImpl({
    required this.db,
    required this.remote,
  });

  String _extractDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.first.toString() : msg.toString();
    }
    return fallback;
  }

  @override
  Future<Result<BarberEntity?>> getBarberByUserId(String userId) async {
    try {
      final map = await remote.getMyBarberIncome();
      final shopMap = map['shop'] is Map
          ? Map<String, dynamic>.from(map['shop'] as Map)
          : null;
      if (shopMap != null) {
        final shopModel = ShopModel.fromJson(shopMap);
        final sIdx = db.shops.indexWhere((s) => s.id == shopModel.id);
        if (sIdx == -1) {
          db.shops.add(shopModel);
        } else {
          db.shops[sIdx] = shopModel;
        }
      }
      final barber = BarberEntity(
        id: (map['barberId'] ?? '').toString(),
        userId: userId,
        shopId: (shopMap?['id'] ?? '').toString(),
        fullName: db.currentUser?.fullName ?? 'Barber',
        email: db.currentUser?.email ?? '',
        phone: db.currentUser?.phone ?? '',
        avatarUrl: db.currentUser?.avatarUrl,
        baseSalary: (map['baseSalary'] as num?)?.toInt() ?? 0,
        isActive: map['isActive'] as bool? ?? true,
        invitationAccepted: true,
      );
      final idx = db.barbers.indexWhere((b) => b.id == barber.id);
      if (idx == -1) {
        db.barbers.add(barber);
      } else {
        db.barbers[idx] = barber;
      }
      return Result.success(barber);
    } catch (_) {}

    final idx = db.barbers.indexWhere((b) => b.userId == userId);
    if (idx == -1) return Result.success(null);
    return Result.success(db.barbers[idx]);
  }

  @override
  Future<Result<UserEntity>> searchUserForInvite(String emailOrPhone) async {
    final q = emailOrPhone.trim().toLowerCase();
    if (q.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng nhập Email hoặc Số điện thoại'),
      );
    }

    try {
      final candidates = await remote.searchBarberCandidates(q);
      if (candidates.isEmpty) {
        return Result.failure(
          const ValidationFailure(
            'Không tìm thấy người dùng với Email/SĐT này',
          ),
        );
      }
      return Result.success(candidates.first);
    } catch (_) {}

    final idx = db.users.indexWhere(
      (u) => u.email.toLowerCase() == q || u.phone == q,
    );
    if (idx == -1) {
      return Result.failure(
        const ValidationFailure(
          'Không tìm thấy người dùng với Email/SĐT này',
        ),
      );
    }
    return Result.success(db.users[idx]);
  }

  @override
  Future<Result<void>> inviteBarberToShop({
    required String managerId,
    required String shopId,
    required String emailOrPhone,
    required int baseSalary,
  }) async {
    try {
      await remote.inviteBarber(emailOrPhone, baseSalary: baseSalary);
      return Result.success(null);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(
            _extractDioError(e, 'Không thể gửi lời mời làm Barber'),
          ),
        );
      }
    } catch (_) {}

    final searchRes = await searchUserForInvite(emailOrPhone);
    if (searchRes.isFailure) {
      return Result.failure(searchRes.failure!);
    }
    final targetUser = searchRes.data!;

    if (targetUser.id == managerId || targetUser.role == UserRole.manager) {
      return Result.failure(
        const ConflictFailure(
          'Quản lý quán KHÔNG được làm Barber (hoặc mời Quản lý khác)!',
        ),
      );
    }

    final existingBarberIdx =
        db.barbers.indexWhere((b) => b.userId == targetUser.id);
    if (existingBarberIdx != -1) {
      final existingBarber = db.barbers[existingBarberIdx];
      if (existingBarber.shopId == shopId) {
        return Result.failure(
          const ConflictFailure('Nhân sự này đã là Barber trong quán của bạn!'),
        );
      }
      return Result.failure(
        const ConflictFailure(
          'Tài khoản này đã là Barber thuộc một quán khác. Một Barber chỉ thuộc tối đa 1 quán!',
        ),
      );
    }

    final shopIdx = db.shops.indexWhere((s) => s.id == shopId);
    final shopName = shopIdx != -1 ? db.shops[shopIdx].name : 'Quán cắt tóc';
    final notifId = 'notif_inv_${DateTime.now().millisecondsSinceEpoch}';

    db.pendingInvitePayloadByNotifId[notifId] = (
      shopId: shopId,
      baseSalary: baseSalary > 0 ? baseSalary : 6000000,
    );

    db.notifications.insert(
      0,
      AppNotificationEntity(
        id: notifId,
        userId: targetUser.id,
        title: 'Lời mời trở thành Barber tại $shopName',
        body:
            'Mức lương cứng đề xuất: ${AppFormatters.formatVnd(baseSalary > 0 ? baseSalary : 6000000)} + 10% hoa hồng dịch vụ. Nhấn Đồng ý để nhận việc!',
        type: NotificationType.barberInvitation,
        targetShopId: shopId,
        createdAt: DateTime.now(),
      ),
    );

    return Result.success(null);
  }

  @override
  Future<Result<UserEntity>> respondBarberInvitation({
    required String notificationId,
    required String userId,
    required bool accept,
  }) async {
    try {
      await remote.respondBarberInvitation(notificationId, accept);
      final updatedUser = await remote.getMe();
      db.currentUser = updatedUser;
      return Result.success(updatedUser);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(_extractDioError(e, 'Không thể phản hồi lời mời')),
        );
      }
    } catch (_) {}

    final nIdx = db.notifications.indexWhere((n) => n.id == notificationId);
    if (nIdx != -1) {
      db.notifications[nIdx] = db.notifications[nIdx].copyWith(
        isRead: true,
        payload: {
          ...?db.notifications[nIdx].payload,
          'responded': true,
          'accepted': accept,
        },
      );
    }

    final uIdx = db.users.indexWhere((u) => u.id == userId);
    if (uIdx == -1) {
      return Result.failure(const AuthFailure('Không tìm thấy người dùng'));
    }

    final payload = db.pendingInvitePayloadByNotifId.remove(notificationId);
    if (!accept || payload == null) {
      return Result.success(db.users[uIdx]);
    }

    if (db.barbers.any((b) => b.userId == userId)) {
      return Result.failure(
        const ConflictFailure('Bạn đã thuộc một quán cắt tóc khác!'),
      );
    }

    final user = db.users[uIdx];
    final promoted = user.copyWith(role: UserRole.barber);
    db.users[uIdx] = promoted;
    if (db.currentUser?.id == userId) {
      db.currentUser = promoted;
    }

    db.barbers.add(
      BarberEntity(
        id: 'barber_${DateTime.now().millisecondsSinceEpoch}',
        userId: promoted.id,
        shopId: payload.shopId,
        fullName: promoted.fullName,
        email: promoted.email,
        phone: promoted.phone,
        avatarUrl: promoted.avatarUrl,
        baseSalary: payload.baseSalary,
        isActive: true,
        invitationAccepted: true,
      ),
    );

    return Result.success(promoted);
  }

  @override
  Future<Result<BarberEntity>> updateBarberBaseSalary({
    required String barberId,
    required int baseSalary,
  }) async {
    if (baseSalary < 0) {
      return Result.failure(
        const ValidationFailure('Lương cứng không được nhỏ hơn 0'),
      );
    }
    try {
      await remote.updateBarberSalary(barberId, baseSalary);
    } catch (_) {}

    final idx = db.barbers.indexWhere((b) => b.id == barberId);
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy Barber'));
    }
    final updated = db.barbers[idx].copyWith(baseSalary: baseSalary);
    db.barbers[idx] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> removeBarberFromShop({
    required String barberId,
  }) async {
    try {
      await remote.removeBarber(barberId);
      db.barbers.removeWhere((b) => b.id == barberId);
      return Result.success(null);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(_extractDioError(e, 'Không thể xoá Barber')),
        );
      }
    } catch (_) {}

    final idx = db.barbers.indexWhere((b) => b.id == barberId);
    if (idx != -1) {
      final removed = db.barbers.removeAt(idx);
      final uIdx = db.users.indexWhere((u) => u.id == removed.userId);
      if (uIdx != -1) {
        db.users[uIdx] = db.users[uIdx].copyWith(role: UserRole.user);
      }
      db.notifications.insert(
        0,
        AppNotificationEntity(
          id: 'notif_rm_${DateTime.now().millisecondsSinceEpoch}',
          userId: removed.userId,
          title: 'Thông báo từ quán cắt tóc',
          body:
              'Quản lý quán đã kết thúc hợp tác Barber với tài khoản của bạn.',
          type: NotificationType.system,
          createdAt: DateTime.now(),
        ),
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<MonthlyBookingHeatDay>>> getMonthlyHeatmap({
    required String barberId,
    required int year,
    required int month,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    try {
      final heatMap = await remote.getMyBarberHeatmap(year, month);
      final list = <MonthlyBookingHeatDay>[];
      for (int d = 1; d <= daysInMonth; d++) {
        final count = (heatMap['$d'] as num?)?.toInt() ?? 0;
        list.add(
          MonthlyBookingHeatDay(
            date: DateTime(year, month, d),
            totalBookings: count,
            completedBookings: 0,
          ),
        );
      }
      return Result.success(list);
    } catch (_) {}

    final list = <MonthlyBookingHeatDay>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final dayDate = DateTime(year, month, d);
      final dayBookings = db.bookings.where(
        (b) =>
            b.barberId == barberId &&
            b.status != BookingStatus.cancelled &&
            b.isSameDay(dayDate),
      );
      final completed = dayBookings
          .where((b) => b.status == BookingStatus.completed)
          .length;
      list.add(
        MonthlyBookingHeatDay(
          date: dayDate,
          totalBookings: dayBookings.length,
          completedBookings: completed,
        ),
      );
    }
    return Result.success(list);
  }

  @override
  Future<Result<List<BookingEntity>>> getBarberDayBookings({
    required String barberId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final remoteList = await remote.getMyBarberTimeline(dateStr);
      return Result.success(remoteList);
    } catch (_) {}

    final list = db.bookings
        .where(
          (b) =>
              b.barberId == barberId &&
              b.status != BookingStatus.cancelled &&
              b.isSameDay(date),
        )
        .toList();
    list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return Result.success(list);
  }

  @override
  Future<Result<BarberIncomeSummary>> getBarberIncomeSummary(
    String barberId,
  ) async {
    try {
      final map = await remote.getMyBarberIncome();
      final baseSalary = (map['baseSalary'] as num?)?.toInt() ?? 0;
      final completedCount =
          (map['completedBookingsCount'] as num?)?.toInt() ?? 0;
      final rev = (map['completedRevenue'] as num?)?.toInt() ?? 0;
      final comm = (map['commissionAmount'] as num?)?.toInt() ?? 0;
      final total = (map['totalIncome'] as num?)?.toInt() ?? (baseSalary + comm);
      return Result.success(
        BarberIncomeSummary(
          barberId: (map['barberId'] ?? barberId).toString(),
          barberName: db.currentUser?.fullName ?? 'Barber',
          baseSalary: baseSalary,
          completedCustomerCount: completedCount,
          completedServiceRevenue: rev,
          commissionAmount: comm,
          totalIncome: total,
          expectedPaydayText:
              (map['expectedPaydayNote'] ?? AppConstants.expectedPaydayText)
                  .toString(),
        ),
      );
    } catch (_) {}

    final idx = db.barbers.indexWhere((b) => b.id == barberId);
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy Barber'));
    }
    final barber = db.barbers[idx];

    final completedBookings = db.bookings
        .where(
          (b) => b.barberId == barberId && b.status == BookingStatus.completed,
        )
        .toList();

    final serviceRev = completedBookings.fold<int>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    final commission =
        (serviceRev * AppConstants.barberCommissionRate).round();

    return Result.success(
      BarberIncomeSummary(
        barberId: barber.id,
        barberName: barber.fullName,
        baseSalary: barber.baseSalary,
        completedCustomerCount: completedBookings.length,
        completedServiceRevenue: serviceRev,
        commissionAmount: commission,
        totalIncome: barber.baseSalary + commission,
        expectedPaydayText: AppConstants.expectedPaydayText,
      ),
    );
  }
}
