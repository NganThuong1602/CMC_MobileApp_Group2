import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/network/socket_service.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/barber_entity.dart';
import '../../domain/entities/finance_entities.dart';
import '../../domain/entities/payment_transaction_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/shop_entity.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/local/in_memory_database.dart';
import '../datasources/remote/remote_api_datasource.dart';

class ShopRepositoryImpl implements ShopRepository {
  final InMemoryDatabase db;
  final RemoteApiDataSource remote;
  final SocketService socketService;

  const ShopRepositoryImpl({
    required this.db,
    required this.remote,
    required this.socketService,
  });

  void _syncShopToLocal(ShopEntity shop) {
    final idx = db.shops.indexWhere((s) => s.id == shop.id);
    if (idx == -1) {
      db.shops.add(shop);
    } else {
      db.shops[idx] = shop;
    }
  }

  void _syncShopBundle(ShopDetailBundle bundle) {
    _syncShopToLocal(bundle.shop);
    for (final srv in bundle.services) {
      final idx = db.services.indexWhere((s) => s.id == srv.id);
      if (idx == -1) {
        db.services.add(srv);
      } else {
        db.services[idx] = srv;
      }
    }
    for (final b in bundle.barbers) {
      final idx = db.barbers.indexWhere((x) => x.id == b.id);
      if (idx == -1) {
        db.barbers.add(b);
      } else {
        db.barbers[idx] = b;
      }
    }
    for (final r in bundle.reviews) {
      final idx = db.reviews.indexWhere((x) => x.id == r.id);
      if (idx == -1) {
        db.reviews.add(r);
      } else {
        db.reviews[idx] = r;
      }
    }
  }

  String _extractDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.first.toString() : msg.toString();
    }
    return fallback;
  }

  @override
  Future<Result<List<ShopEntity>>> getNearbyShops({
    double? userLat,
    double? userLng,
    String? searchQuery,
    double? minRating,
  }) async {
    try {
      final remoteList = await remote.getNearbyShops(
        lat: userLat,
        lng: userLng,
        search: searchQuery,
        minRating: minRating,
      );
      for (final s in remoteList) {
        _syncShopToLocal(s);
      }
      return Result.success(remoteList);
    } catch (_) {}

    final lat = userLat ?? AppConstants.defaultLat;
    final lng = userLng ?? AppConstants.defaultLng;
    final query = (searchQuery ?? '').trim().toLowerCase();

    var result = db.shops.map((shop) {
      final dist = db.calculateDistanceKm(
        lat,
        lng,
        shop.latitude,
        shop.longitude,
      );
      return shop.copyWith(
        distanceKm: double.parse(dist.toStringAsFixed(1)),
      );
    }).where((shop) {
      if (minRating != null && shop.rating < minRating) return false;
      if (query.isEmpty) return true;
      return shop.name.toLowerCase().contains(query) ||
          shop.address.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return Result.success(result);
  }

  @override
  Future<Result<List<ShopEntity>>> getHighlightedShops() async {
    try {
      final remoteList = await remote.getHighlightedShops();
      for (final s in remoteList) {
        _syncShopToLocal(s);
      }
      return Result.success(remoteList);
    } catch (_) {}

    final now = DateTime.now();
    final list = db.shops.where((s) => s.isHighlightedAt(now)).toList();
    return Result.success(list);
  }

  @override
  Future<Result<ShopEntity>> getShopById(String shopId) async {
    try {
      final bundle = await remote.getShopDetail(shopId);
      _syncShopBundle(bundle);
      return Result.success(bundle.shop);
    } catch (_) {}

    final idx = db.shops.indexWhere((s) => s.id == shopId);
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy quán'));
    }
    return Result.success(db.shops[idx]);
  }

  @override
  Future<Result<ShopEntity?>> getShopByOwnerId(String ownerId) async {
    try {
      final bundle = await remote.getMyOwnedShop();
      if (bundle != null) {
        _syncShopBundle(bundle);
        return Result.success(bundle.shop);
      }
    } catch (_) {}

    final idx = db.shops.indexWhere((s) => s.ownerId == ownerId);
    if (idx == -1) return Result.success(null);
    return Result.success(db.shops[idx]);
  }

  @override
  Future<Result<List<ServiceEntity>>> getShopServices(String shopId) async {
    try {
      final bundle = await remote.getShopDetail(shopId);
      _syncShopBundle(bundle);
      return Result.success(bundle.services);
    } catch (_) {}

    final list = db.services.where((s) => s.shopId == shopId).toList();
    return Result.success(list);
  }

  @override
  Future<Result<List<BarberEntity>>> getShopBarbers(String shopId) async {
    try {
      final bundle = await remote.getShopDetail(shopId);
      _syncShopBundle(bundle);
      return Result.success(bundle.barbers);
    } catch (_) {}

    final list = db.barbers
        .where((b) => b.shopId == shopId && b.invitationAccepted)
        .toList();
    return Result.success(list);
  }

  @override
  Future<Result<PaymentTransactionEntity>> createRegisterShopPayment({
    required String userId,
    required String name,
    required String address,
    required String phone,
    required String description,
    required String openTime,
    required String closeTime,
    required double latitude,
    required double longitude,
    String? coverImageUrl,
  }) async {
    final cleanName = name.trim();
    final cleanAddr = address.trim();
    if (cleanName.isEmpty || cleanAddr.isEmpty || phone.trim().isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng nhập đầy đủ Tên quán, Địa chỉ và SĐT'),
      );
    }

    final resolvedCover =
        (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
            ? coverImageUrl.trim()
            : 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80';

    try {
      final tx = await remote.createRegisterShopQr({
        'name': cleanName,
        'address': cleanAddr,
        'phone': phone.trim(),
        'openTime': openTime,
        'closeTime': closeTime,
        'description': description.trim().isEmpty
            ? 'Không gian cắt tóc chuyên nghiệp dành cho phái mạnh.'
            : description.trim(),
        'coverUrl': resolvedCover,
        'galleryUrls': [resolvedCover],
        'latitude': latitude,
        'longitude': longitude,
      });
      db.transactions.removeWhere((t) => t.paymentCode == tx.paymentCode);
      db.transactions.add(tx);
      return Result.success(tx);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ConflictFailure(_extractDioError(e, 'Không thể khởi tạo đăng ký quán')),
        );
      }
    } catch (_) {}

    final userIdx = db.users.indexWhere((u) => u.id == userId);
    if (userIdx != -1) {
      final user = db.users[userIdx];
      if (user.role == UserRole.manager ||
          db.shops.any((s) => s.ownerId == userId)) {
        return Result.failure(
          const ConflictFailure('Mỗi Quản lý chỉ được sở hữu tối đa 1 quán!'),
        );
      }
      if (user.role == UserRole.barber ||
          db.barbers.any((b) => b.userId == userId)) {
        return Result.failure(
          const ConflictFailure('Tài khoản đang là Barber không thể mở quán!'),
        );
      }
    }

    final codeDigits =
        (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
    final paymentCode = 'PAYSHOP$codeDigits';
    final transferContent = 'PAY SHOP $codeDigits';
    const amount = AppConstants.shopRegistrationFeeVnd;

    final tx = PaymentTransactionEntity(
      id: 'tx_$codeDigits',
      userId: userId,
      type: 'REGISTER_SHOP',
      amount: amount,
      paymentCode: paymentCode,
      transferContent: transferContent,
      qrImageUrl: db.buildVietQrUrl(
        amount: amount,
        transferContent: transferContent,
      ),
      status: 'PENDING',
    );

    db.transactions.add(tx);
    db.pendingShopDraftsByPaymentCode[paymentCode] = PendingShopDraft(
      userId: userId,
      name: cleanName,
      address: cleanAddr,
      phone: phone.trim(),
      description: description.trim().isEmpty
          ? 'Không gian cắt tóc chuyên nghiệp dành cho phái mạnh.'
          : description.trim(),
      openTime: openTime,
      closeTime: closeTime,
      latitude: latitude,
      longitude: longitude,
      coverImageUrl: resolvedCover,
    );

    return Result.success(tx);
  }

  @override
  Future<Result<PaymentTransactionEntity>> createHighlightPayment({
    required String userId,
    required String shopId,
    required HighlightPackageType packageType,
  }) async {
    final apiPlan = switch (packageType) {
      HighlightPackageType.oneHour => 'ONE_HOUR',
      HighlightPackageType.oneDay => 'ONE_DAY',
      HighlightPackageType.threeDays => 'THREE_DAYS',
    };

    try {
      final tx = await remote.createHighlightQr(apiPlan);
      db.transactions.removeWhere((t) => t.paymentCode == tx.paymentCode);
      db.transactions.add(tx);
      return Result.success(tx);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể tạo mã QR gói Nổi bật'),
          ),
        );
      }
    } catch (_) {}

    final codeDigits =
        (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
    final paymentCode = 'PAYHIGHLIGHT$codeDigits';
    final transferContent = 'PAY HIGHLIGHT $codeDigits';
    final amount = packageType.priceVnd;

    final tx = PaymentTransactionEntity(
      id: 'tx_$codeDigits',
      userId: userId,
      type: 'BUY_HIGHLIGHT',
      amount: amount,
      paymentCode: paymentCode,
      transferContent: transferContent,
      qrImageUrl: db.buildVietQrUrl(
        amount: amount,
        transferContent: transferContent,
      ),
      status: 'PENDING',
      referenceId: shopId,
    );

    db.transactions.add(tx);
    db.pendingHighlightByPaymentCode[paymentCode] = (
      shopId: shopId,
      packageType: packageType,
    );
    return Result.success(tx);
  }

  @override
  Future<Result<PaymentTransactionEntity>> simulateSePayWebhook(
    String paymentCode,
  ) async {
    final txIdx =
        db.transactions.indexWhere((t) => t.paymentCode == paymentCode);
    if (txIdx == -1) {
      return Result.failure(
        const ValidationFailure('Không tìm thấy giao dịch QR'),
      );
    }

    final tx = db.transactions[txIdx];
    try {
      await remote.triggerSePayWebhook(
        transferContent: tx.transferContent,
        amount: tx.amount,
      );
    } catch (_) {}

    final completedTx = PaymentTransactionEntity(
      id: tx.id,
      userId: tx.userId,
      type: tx.type,
      amount: tx.amount,
      paymentCode: tx.paymentCode,
      transferContent: tx.transferContent,
      qrImageUrl: tx.qrImageUrl,
      status: 'SUCCESS',
      referenceId: tx.referenceId,
    );
    db.transactions[txIdx] = completedTx;

    if (tx.type == 'REGISTER_SHOP') {
      final draft = db.pendingShopDraftsByPaymentCode.remove(paymentCode);
      if (draft != null) {
        final newShopId = 'shop_${DateTime.now().millisecondsSinceEpoch}';
        db.shops.insert(
          0,
          ShopEntity(
            id: newShopId,
            ownerId: draft.userId,
            name: draft.name,
            address: draft.address,
            phone: draft.phone,
            description: draft.description,
            coverImageUrl: draft.coverImageUrl,
            galleryUrls: [draft.coverImageUrl],
            latitude: draft.latitude,
            longitude: draft.longitude,
            openTime: draft.openTime,
            closeTime: draft.closeTime,
            rating: 5.0,
            reviewCount: 0,
            distanceKm: 0.5,
          ),
        );
        db.services.add(
          ServiceEntity(
            id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
            shopId: newShopId,
            name: 'Cắt tạo kiểu tiêu chuẩn',
            price: 80000,
            durationMinutes: 30,
          ),
        );

        final uIdx = db.users.indexWhere((u) => u.id == draft.userId);
        if (uIdx != -1) {
          final promoted = db.users[uIdx].copyWith(role: UserRole.manager);
          db.users[uIdx] = promoted;
          if (db.currentUser?.id == promoted.id) {
            db.currentUser = promoted;
          }
        }
      }
    } else if (tx.type == 'BUY_HIGHLIGHT') {
      final pkg = db.pendingHighlightByPaymentCode.remove(paymentCode);
      if (pkg != null) {
        final sIdx = db.shops.indexWhere((s) => s.id == pkg.shopId);
        if (sIdx != -1) {
          final currentExp = db.shops[sIdx].highlightExpiresAt;
          final now = DateTime.now();
          final baseTime =
              (currentExp != null && currentExp.isAfter(now)) ? currentExp : now;
          db.shops[sIdx] = db.shops[sIdx].copyWith(
            highlightExpiresAt: baseTime.add(pkg.packageType.duration),
          );
        }
      }
    } else if (tx.type == 'BOOKING_PAYMENT') {
      final bookingId = db.pendingBookingIdByPaymentCode.remove(paymentCode);
      if (bookingId != null) {
        final bIdx = db.bookings.indexWhere((b) => b.id == bookingId);
        if (bIdx != -1) {
          db.bookings[bIdx] = db.bookings[bIdx].copyWith(
            status: BookingStatus.completed,
            isPaid: true,
          );
          db.notifications.insert(
            0,
            AppNotificationEntity(
              id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
              userId: db.bookings[bIdx].customerId,
              title: 'Thanh toán QR thành công (SePay)',
              body:
                  'Lịch cắt tóc tại ${db.bookings[bIdx].shopName} đã tự động chuyển sang Hoàn thành!',
              type: NotificationType.paymentConfirmed,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    socketService.emitSimulatedPaymentSuccess({
      'paymentCode': completedTx.paymentCode,
      'type': completedTx.type,
      'amount': completedTx.amount,
      'status': 'SUCCESS',
    });

    return Result.success(completedTx);
  }

  @override
  Future<Result<ShopEntity>> updateShopInfo({
    required String shopId,
    required String name,
    required String address,
    required String phone,
    required String description,
    required String openTime,
    required String closeTime,
    String? coverImageUrl,
    List<String>? galleryUrls,
  }) async {
    try {
      final updatedRemote = await remote.updateShop(shopId, {
        'name': name.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'description': description.trim(),
        'openTime': openTime,
        'closeTime': closeTime,
        if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
          'coverUrl': coverImageUrl.trim(),
        if (galleryUrls != null) 'galleryUrls': galleryUrls,
      });
      _syncShopToLocal(updatedRemote);
      return Result.success(updatedRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể cập nhật thông tin quán'),
          ),
        );
      }
    } catch (_) {}

    final idx = db.shops.indexWhere((s) => s.id == shopId);
    if (idx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy quán'));
    }
    final updated = db.shops[idx].copyWith(
      name: name.trim(),
      address: address.trim(),
      phone: phone.trim(),
      description: description.trim(),
      openTime: openTime,
      closeTime: closeTime,
      coverImageUrl: coverImageUrl ?? db.shops[idx].coverImageUrl,
      galleryUrls: galleryUrls ?? db.shops[idx].galleryUrls,
    );
    db.shops[idx] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<ServiceEntity>> upsertService({
    required String shopId,
    String? serviceId,
    required String name,
    required int price,
    required int durationMinutes,
    String? imageUrl,
  }) async {
    if (name.trim().isEmpty || price <= 0 || durationMinutes <= 0) {
      return Result.failure(
        const ValidationFailure('Tên, giá và thời lượng dịch vụ phải hợp lệ'),
      );
    }

    if (serviceId == null) {
      try {
        final created = await remote.createShopService(
          shopId: shopId,
          name: name.trim(),
          price: price,
          durationMinutes: durationMinutes,
        );
        db.services.add(created);
        return Result.success(created);
      } catch (_) {}
    }

    final entity = ServiceEntity(
      id: serviceId ?? 'srv_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      name: name.trim(),
      price: price,
      durationMinutes: durationMinutes,
      imageUrl: imageUrl,
    );
    if (serviceId != null) {
      final idx = db.services.indexWhere((s) => s.id == serviceId);
      if (idx != -1) {
        db.services[idx] = entity;
        return Result.success(entity);
      }
    }
    db.services.add(entity);
    return Result.success(entity);
  }

  @override
  Future<Result<void>> deleteService({
    required String shopId,
    required String serviceId,
  }) async {
    try {
      await remote.deleteShopService(serviceId);
    } catch (_) {}
    db.services.removeWhere((s) => s.id == serviceId && s.shopId == shopId);
    return Result.success(null);
  }

  @override
  Future<Result<ShopRevenueSummary>> getShopRevenueAndPayroll(
    String shopId,
  ) async {
    try {
      final map = await remote.getShopPayroll(shopId);
      final totalShopRevenue = (map['totalShopRevenue'] as num?)?.toInt() ?? 0;
      final completedCount =
          (map['completedBookingsCount'] as num?)?.toInt() ?? 0;
      final rawPayrolls = (map['barberPayrolls'] as List?) ?? const [];

      int totalBarberPayout = 0;
      final payrolls = <BarberPayrollItem>[];
      for (final raw in rawPayrolls.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final baseSalary = (item['baseSalary'] as num?)?.toInt() ?? 0;
        final rev = (item['bookedCompletedRevenue'] as num?)?.toInt() ?? 0;
        final comm = (item['commissionAmount'] as num?)?.toInt() ?? 0;
        final total = (item['totalSalary'] as num?)?.toInt() ?? (baseSalary + comm);
        totalBarberPayout += total;
        payrolls.add(
          BarberPayrollItem(
            barberId: (item['barberId'] ?? '').toString(),
            barberName: (item['fullName'] ?? 'Barber').toString(),
            baseSalary: baseSalary,
            completedCustomerCount: rev > 0 ? 1 : 0,
            generatedRevenue: rev,
            commissionAmount: comm,
            totalPayout: total,
          ),
        );
      }

      return Result.success(
        ShopRevenueSummary(
          shopId: shopId,
          completedBookingCount: completedCount,
          totalShopRevenue: totalShopRevenue,
          totalBarberPayout: totalBarberPayout,
          netProfit: totalShopRevenue - totalBarberPayout,
          barberPayrolls: payrolls,
        ),
      );
    } catch (_) {}

    final completedBookings = db.bookings
        .where(
          (b) => b.shopId == shopId && b.status == BookingStatus.completed,
        )
        .toList();

    final shopBarbers =
        db.barbers.where((b) => b.shopId == shopId && b.invitationAccepted).toList();

    int totalShopRevenue = 0;
    for (final b in completedBookings) {
      totalShopRevenue += b.totalPrice;
    }

    final payrolls = <BarberPayrollItem>[];
    int totalBarberPayout = 0;

    for (final barber in shopBarbers) {
      final barberCompleted =
          completedBookings.where((b) => b.barberId == barber.id).toList();
      final generatedRev = barberCompleted.fold<int>(
        0,
        (sum, item) => sum + item.totalPrice,
      );
      final commission =
          (generatedRev * AppConstants.barberCommissionRate).round();
      final payout = barber.baseSalary + commission;
      totalBarberPayout += payout;

      payrolls.add(
        BarberPayrollItem(
          barberId: barber.id,
          barberName: barber.fullName,
          baseSalary: barber.baseSalary,
          completedCustomerCount: barberCompleted.length,
          generatedRevenue: generatedRev,
          commissionAmount: commission,
          totalPayout: payout,
        ),
      );
    }

    return Result.success(
      ShopRevenueSummary(
        shopId: shopId,
        completedBookingCount: completedBookings.length,
        totalShopRevenue: totalShopRevenue,
        totalBarberPayout: totalBarberPayout,
        netProfit: totalShopRevenue - totalBarberPayout,
        barberPayrolls: payrolls,
      ),
    );
  }
}
