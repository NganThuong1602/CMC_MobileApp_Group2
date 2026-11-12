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

  static final List<DiscountCodeEntity> _offlineDiscountCodes = [];
  static final Map<String, ShopPackagePlan> _pendingPackageByPaymentCode = {};
  static final Map<
      String,
      ({
        ShopPackagePlan packagePlan,
        String paymentCode,
        int amount,
        DateTime paidAt,
      })> _paidCreditByUserId = {};
  static final Map<String, ({String shopId, ShopPackagePlan packagePlan})>
      _pendingRenewByPaymentCode = {};

  void _syncActiveDiscountsToOfflineShops() {
    final now = DateTime.now();
    final active = _offlineDiscountCodes
        .where(
          (d) =>
              d.isActive && !now.isBefore(d.startAt) && !now.isAfter(d.endAt),
        )
        .toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final best = active.isNotEmpty ? active.first : null;
    for (var i = 0; i < db.shops.length; i++) {
      final s = db.shops[i];
      if (s.isCooperation && s.isActive) {
        db.shops[i] = s.copyWith(
          activeDiscountPercent: best?.discountPercent ?? 0,
          activeDiscountName: best?.name,
          activeDiscountCode: best?.code,
        );
      } else if (s.activeDiscountPercent != 0) {
        db.shops[i] = s.copyWith(
          activeDiscountPercent: 0,
        );
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
    bool onlyHighlighted = false,
  }) async {
    try {
      final remoteList = await remote.getNearbyShops(
        lat: userLat,
        lng: userLng,
        search: searchQuery,
        minRating: minRating,
        onlyHighlighted: onlyHighlighted,
      );
      for (final s in remoteList) {
        _syncShopToLocal(s);
      }
      var list = remoteList.where((s) => s.isActive).toList();
      if (onlyHighlighted) {
        final now = DateTime.now();
        list = list.where((s) => s.isHighlightedAt(now)).toList();
      }
      return Result.success(list);
    } catch (_) {}

    _syncActiveDiscountsToOfflineShops();
    final now = DateTime.now();
    var list = db.shops.where((s) => s.isActive).toList();
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.address.toLowerCase().contains(q),
          )
          .toList();
    }
    if (minRating != null) {
      list = list.where((s) => s.reviewCount > 0 && s.rating >= minRating).toList();
    }
    if (onlyHighlighted) {
      list = list.where((s) => s.isHighlightedAt(now)).toList();
    }
    if (userLat != null && userLng != null) {
      list = list
          .map(
            (s) => s.copyWith(
              distanceKm: double.parse(
                db
                    .calculateDistanceKm(
                      userLat,
                      userLng,
                      s.latitude,
                      s.longitude,
                    )
                    .toStringAsFixed(1),
              ),
            ),
          )
          .toList();
    }
    list.sort((a, b) {
      final ha = a.isHighlightedAt(now) ? 1 : 0;
      final hb = b.isHighlightedAt(now) ? 1 : 0;
      if (ha != hb) return hb.compareTo(ha);
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return Result.success(list);
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
    final list =
        db.shops.where((s) => s.isActive && s.isHighlightedAt(now)).toList();
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
      // Khi Backend trả về null (chưa đăng ký hoặc đã bị Admin từ chối/xoá) -> xoá cache cũ để cho phép đăng ký lại
      db.shops.removeWhere((s) => s.ownerId == ownerId);
      return Result.success(null);
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

    final resolvedDesc = description.trim().isEmpty
        ? 'Không gian cắt tóc chuyên nghiệp dành cho phái mạnh.'
        : description.trim();

    try {
      final tx = await remote.createRegisterShopQr({
        'name': cleanName,
        'address': cleanAddr,
        'phone': phone.trim(),
        'openTime': openTime,
        'closeTime': closeTime,
        'description': resolvedDesc,
        'coverUrl': resolvedCover,
        'galleryUrls': [resolvedCover],
        'latitude': latitude,
        'longitude': longitude,
      });
      db.transactions.removeWhere((t) => t.paymentCode == tx.paymentCode);
      db.transactions.add(tx);
      db.pendingShopDraftsByPaymentCode[tx.paymentCode] = PendingShopDraft(
        userId: userId,
        name: cleanName,
        address: cleanAddr,
        phone: phone.trim(),
        description: resolvedDesc,
        openTime: openTime,
        closeTime: closeTime,
        latitude: latitude,
        longitude: longitude,
        coverImageUrl: resolvedCover,
      );
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
    bool remoteSynced = false;
    PaymentTransactionEntity? remoteTx;
    try {
      remoteTx = await remote.triggerSePayWebhook(
        transferContent: tx.transferContent,
        amount: tx.amount,
      );
      if (tx.type == 'REGISTER_SHOP') {
        final bundle = await remote.getMyOwnedShop();
        if (bundle != null) {
          _syncShopBundle(bundle);
          db.pendingShopDraftsByPaymentCode.remove(paymentCode);
          remoteSynced = true;
        }
      }
    } catch (_) {}

    final completedTx = PaymentTransactionEntity(
      id: remoteTx?.id.isNotEmpty == true ? remoteTx!.id : tx.id,
      userId: tx.userId,
      type: tx.type,
      amount: tx.amount,
      paymentCode: tx.paymentCode,
      transferContent: tx.transferContent,
      qrImageUrl: tx.qrImageUrl,
      status: 'SUCCESS',
      referenceId: remoteTx?.referenceId ?? tx.referenceId,
    );
    db.transactions[txIdx] = completedTx;

    if (tx.type == 'REGISTER_SHOP' && !remoteSynced) {
      final draft = db.pendingShopDraftsByPaymentCode.remove(paymentCode);
      if (draft != null) {
        final newShopId = 'shop_${DateTime.now().millisecondsSinceEpoch}';
        final ownerIdx = db.users.indexWhere((u) => u.id == draft.userId);
        final ownerUser = ownerIdx != -1 ? db.users[ownerIdx] : db.currentUser;
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
            isActive: false, // Chờ duyệt bởi Admin
            ownerName: ownerUser?.fullName ?? '',
            ownerPhone: ownerUser?.phone ?? '',
            ownerEmail: ownerUser?.email ?? '',
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

        for (final admin in db.users.where((u) => u.role == UserRole.admin)) {
          db.notifications.insert(
            0,
            AppNotificationEntity(
              id: 'notif_admin_${DateTime.now().millisecondsSinceEpoch}',
              userId: admin.id,
              title: 'Yêu cầu duyệt mở quán mới',
              body:
                  'Quán "${draft.name}" (${draft.address}) vừa thanh toán lệ phí và đang chờ Admin phê duyệt.',
              type: NotificationType.shopApproval,
              targetShopId: newShopId,
              createdAt: DateTime.now(),
            ),
          );
        }

        db.notifications.insert(
          0,
          AppNotificationEntity(
            id: 'notif_owner_${DateTime.now().millisecondsSinceEpoch}',
            userId: draft.userId,
            title: 'Đã gửi hồ sơ đăng ký quán (Chờ duyệt)',
            body:
                'Quán "${draft.name}" đang ở trạng thái Chờ duyệt bởi Admin hệ thống.',
            type: NotificationType.shopApproval,
            targetShopId: newShopId,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        final pendingPkg = _pendingPackageByPaymentCode.remove(paymentCode);
        if (pendingPkg != null) {
          _paidCreditByUserId[tx.userId] = (
            packagePlan: pendingPkg,
            paymentCode: completedTx.paymentCode,
            amount: completedTx.amount,
            paidAt: DateTime.now(),
          );
          socketService.emitSimulatedPaymentSuccess({
            'paymentCode': completedTx.paymentCode,
            'type': completedTx.type,
            'amount': completedTx.amount,
            'status': 'SUCCESS',
          });
          return Result.success(
            PaymentTransactionEntity(
              id: completedTx.id,
              userId: completedTx.userId,
              type: completedTx.type,
              amount: completedTx.amount,
              paymentCode: completedTx.paymentCode,
              transferContent: completedTx.transferContent,
              qrImageUrl: completedTx.qrImageUrl,
              status: completedTx.status,
              referenceId: completedTx.referenceId,
              packagePlan: pendingPkg.apiValue,
              readyForShopForm: true,
            ),
          );
        }
      }
    } else if (tx.type == 'RENEW_SHOP') {
      final renew = _pendingRenewByPaymentCode.remove(paymentCode);
      if (renew != null) {
        final sIdx = db.shops.indexWhere((s) => s.id == renew.shopId);
        if (sIdx != -1) {
          final currentShop = db.shops[sIdx];
          final now = DateTime.now();
          final baseExp = currentShop.subscriptionExpiresAt != null &&
                  currentShop.subscriptionExpiresAt!.isAfter(now)
              ? currentShop.subscriptionExpiresAt!
              : now;
          final nextExp = baseExp.add(
            Duration(days: renew.packagePlan.durationDays),
          );
          final isCoop = renew.packagePlan.isCooperation;
          db.shops[sIdx] = currentShop.copyWith(
            subscriptionPlan: renew.packagePlan,
            isCooperation: isCoop,
            subscriptionExpiresAt: nextExp,
            highlightExpiresAt: isCoop ? nextExp : null,
            serverIsHighlighted: isCoop,
          );
          _syncActiveDiscountsToOfflineShops();
          db.notifications.insert(
            0,
            AppNotificationEntity(
              id: 'notif_renew_${DateTime.now().millisecondsSinceEpoch}',
              userId: currentShop.ownerId,
              title: 'Gia hạn gói quán thành công',
              body:
                  'Quán "${currentShop.name}" đã được gia hạn ${renew.packagePlan.label}.',
              type: NotificationType.paymentConfirmed,
              targetShopId: currentShop.id,
              createdAt: DateTime.now(),
            ),
          );
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
    } else {
      try {
        final updated = await remote.updateShopService(
          serviceId: serviceId,
          name: name.trim(),
          price: price,
          durationMinutes: durationMinutes,
        );
        final idx = db.services.indexWhere((s) => s.id == serviceId);
        if (idx != -1) {
          db.services[idx] = updated;
        } else {
          db.services.add(updated);
        }
        return Result.success(updated);
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
  Future<Result<RegisterShopCredit>> getRegisterShopCredit() async {
    try {
      final map = await remote.getRegisterShopCredit();
      final hasCredit = map['hasCredit'] == true;
      final plan = ShopPackagePlan.fromApi(map['packagePlan']?.toString());
      final paidAtStr = map['paidAt']?.toString();
      return Result.success(
        RegisterShopCredit(
          hasCredit: hasCredit,
          packagePlan: plan,
          amount: (map['amount'] as num?)?.toInt() ?? 0,
          paymentCode: (map['paymentCode'] ?? '').toString(),
          paidAt: paidAtStr != null ? DateTime.tryParse(paidAtStr) : null,
        ),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể kiểm tra trạng thái thanh toán'),
          ),
        );
      }
    } catch (_) {}

    final userId = db.currentUser?.id;
    final offlineCredit =
        userId != null ? _paidCreditByUserId[userId] : null;
    if (offlineCredit == null) {
      return Result.success(const RegisterShopCredit(hasCredit: false));
    }
    return Result.success(
      RegisterShopCredit(
        hasCredit: true,
        packagePlan: offlineCredit.packagePlan,
        amount: offlineCredit.amount,
        paymentCode: offlineCredit.paymentCode,
        paidAt: offlineCredit.paidAt,
      ),
    );
  }

  @override
  Future<Result<PaymentTransactionEntity>> createPackageRegistrationPayment({
    required String userId,
    required ShopPackagePlan packagePlan,
  }) async {
    try {
      final tx = await remote.createRegisterShopQr({
        'packagePlan': packagePlan.apiValue,
      });
      db.transactions.removeWhere((t) => t.paymentCode == tx.paymentCode);
      db.transactions.add(tx);
      return Result.success(tx);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể tạo mã QR thanh toán gói'),
          ),
        );
      }
    } catch (_) {}

    final codeDigits =
        (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
    final paymentCode = 'PAYREG$codeDigits';
    final transferContent = 'PAY REG $codeDigits';
    final amount = packagePlan.price;

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
      packagePlan: packagePlan.apiValue,
    );
    db.transactions.add(tx);
    _pendingPackageByPaymentCode[paymentCode] = packagePlan;
    return Result.success(tx);
  }

  @override
  Future<Result<ShopEntity>> submitShopRegistrationAfterPayment({
    required String userId,
    required String paymentCode,
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
    final resolvedCover =
        coverImageUrl != null && coverImageUrl.trim().isNotEmpty
            ? coverImageUrl.trim()
            : 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80';

    try {
      final created = await remote.submitRegisterShopForm({
        if (paymentCode.trim().isNotEmpty) 'paymentCode': paymentCode.trim(),
        'name': cleanName,
        'address': cleanAddr,
        'phone': phone.trim(),
        'description': description.trim().isEmpty
            ? 'Không gian cắt tóc chuyên nghiệp dành cho phái mạnh.'
            : description.trim(),
        'openTime': openTime,
        'closeTime': closeTime,
        'latitude': latitude,
        'longitude': longitude,
        'coverUrl': resolvedCover,
      });
      _syncShopToLocal(created);
      return Result.success(created);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể gửi hồ sơ đăng ký quán'),
          ),
        );
      }
    } catch (_) {}

    final credit = _paidCreditByUserId.remove(userId);
    if (credit == null) {
      return Result.failure(
        const ValidationFailure('Vui lòng thanh toán gói trước khi đăng ký quán'),
      );
    }
    final dupName = db.shops.any(
      (s) => s.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );
    if (dupName) {
      return Result.failure(
        const ValidationFailure('Tên quán đã tồn tại trên hệ thống'),
      );
    }

    final newShopId = 'shop_${DateTime.now().millisecondsSinceEpoch}';
    final newShop = ShopEntity(
      id: newShopId,
      ownerId: userId,
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
      galleryUrls: const [],
      rating: 0.0,
      reviewCount: 0,
      isActive: false,
      subscriptionPlan: credit.packagePlan,
      isCooperation: credit.packagePlan.isCooperation,
      paymentCode: credit.paymentCode,
      paymentAmount: credit.amount,
      paidAt: credit.paidAt,
    );
    db.shops.add(newShop);

    for (final admin
        in db.users.where((u) => u.role == UserRole.admin).toList()) {
      db.notifications.insert(
        0,
        AppNotificationEntity(
          id: 'notif_admin_${DateTime.now().microsecondsSinceEpoch}',
          userId: admin.id,
          title: 'Yêu cầu mở quán mới: $cleanName',
          body: 'Gói ${credit.packagePlan.label} đã thanh toán. Bấm để duyệt.',
          type: NotificationType.shopApproval,
          targetShopId: newShopId,
          createdAt: DateTime.now(),
        ),
      );
    }
    db.notifications.insert(
      0,
      AppNotificationEntity(
        id: 'notif_owner_${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        title: 'Đã gửi hồ sơ đăng ký quán (Chờ duyệt)',
        body: 'Quán "$cleanName" đang chờ Admin hệ thống phê duyệt.',
        type: NotificationType.shopApproval,
        targetShopId: newShopId,
        createdAt: DateTime.now(),
      ),
    );
    return Result.success(newShop);
  }

  @override
  Future<Result<PaymentTransactionEntity>> createRenewShopPayment({
    required String userId,
    required String shopId,
    required ShopPackagePlan packagePlan,
  }) async {
    try {
      final tx = await remote.createRenewShopQr(packagePlan.apiValue);
      db.transactions.removeWhere((t) => t.paymentCode == tx.paymentCode);
      db.transactions.add(tx);
      return Result.success(tx);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể tạo mã QR gia hạn gói'),
          ),
        );
      }
    } catch (_) {}

    final codeDigits =
        (DateTime.now().millisecondsSinceEpoch % 900000 + 100000).toString();
    final paymentCode = 'PAYRENEW$codeDigits';
    final transferContent = 'PAY RENEW $codeDigits';
    final amount = packagePlan.price;
    final tx = PaymentTransactionEntity(
      id: 'tx_$codeDigits',
      userId: userId,
      type: 'RENEW_SHOP',
      amount: amount,
      paymentCode: paymentCode,
      transferContent: transferContent,
      qrImageUrl: db.buildVietQrUrl(
        amount: amount,
        transferContent: transferContent,
      ),
      status: 'PENDING',
      referenceId: shopId,
      packagePlan: packagePlan.apiValue,
    );
    db.transactions.add(tx);
    _pendingRenewByPaymentCode[paymentCode] = (
      shopId: shopId,
      packagePlan: packagePlan,
    );
    return Result.success(tx);
  }

  @override
  Future<Result<List<DiscountCodeEntity>>> getDiscountCodes() async {
    try {
      final remoteList = await remote.getDiscountCodes();
      _offlineDiscountCodes
        ..clear()
        ..addAll(remoteList);
      _syncActiveDiscountsToOfflineShops();
      return Result.success(remoteList);
    } catch (_) {}
    _syncActiveDiscountsToOfflineShops();
    return Result.success(List.unmodifiable(_offlineDiscountCodes));
  }

  @override
  Future<Result<DiscountCodeEntity>> createDiscountCode({
    required String name,
    String? code,
    required int discountPercent,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final created = await remote.createDiscountCode(
        name: name,
        code: code,
        discountPercent: discountPercent,
        startAt: startAt,
        endAt: endAt,
      );
      _offlineDiscountCodes.insert(0, created);
      _syncActiveDiscountsToOfflineShops();
      return Result.success(created);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể thêm mã giảm giá'),
          ),
        );
      }
    } catch (_) {}

    final created = DiscountCodeEntity(
      id: 'disc_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      code: (code == null || code.trim().isEmpty)
          ? ''
          : code.trim().toUpperCase(),
      discountPercent: discountPercent,
      startAt: startAt,
      endAt: endAt,
      isActive: true,
    );
    _offlineDiscountCodes.insert(0, created);
    _syncActiveDiscountsToOfflineShops();
    return Result.success(created);
  }

  @override
  Future<Result<void>> deleteDiscountCode(String id) async {
    try {
      await remote.deleteDiscountCode(id);
    } catch (_) {}
    _offlineDiscountCodes.removeWhere((d) => d.id == id);
    _syncActiveDiscountsToOfflineShops();
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

  @override
  Future<Result<List<ShopEntity>>> getAdminPendingShops() async {
    try {
      final remoteShops = await remote.getAdminPendingShops();
      return Result.success(remoteShops);
    } catch (_) {}

    final pending = db.shops.where((s) => !s.isActive).toList();
    return Result.success(pending);
  }

  @override
  Future<Result<List<ShopEntity>>> getAdminActiveShops() async {
    try {
      final remoteShops = await remote.getAdminActiveShops();
      return Result.success(remoteShops);
    } catch (_) {}

    final active = db.shops.where((s) => s.isActive).toList();
    return Result.success(active);
  }

  @override
  Future<Result<ShopEntity>> approveShopByAdmin(String shopId) async {
    try {
      final approved = await remote.approveShopByAdmin(shopId);
      final sIdx = db.shops.indexWhere((s) => s.id == shopId);
      if (sIdx != -1) {
        db.shops[sIdx] = approved;
      } else {
        db.shops.add(approved);
      }
      return Result.success(approved);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(_extractDioError(e, 'Không thể phê duyệt quán')),
        );
      }
    } catch (_) {}

    final sIdx = db.shops.indexWhere((s) => s.id == shopId);
    if (sIdx == -1) {
      return Result.failure(const ValidationFailure('Không tìm thấy quán'));
    }
    final approved = db.shops[sIdx].copyWith(isActive: true);
    db.shops[sIdx] = approved;

    final uIdx = db.users.indexWhere((u) => u.id == approved.ownerId);
    if (uIdx != -1 && db.users[uIdx].role != UserRole.admin) {
      db.users[uIdx] = db.users[uIdx].copyWith(role: UserRole.manager);
    }

    db.notifications.insert(
      0,
      AppNotificationEntity(
        id: 'notif_appr_${DateTime.now().millisecondsSinceEpoch}',
        userId: approved.ownerId,
        title: 'Quán của bạn đã được Admin phê duyệt!',
        body:
            'Chúc mừng! Quán "${approved.name}" đã được Admin duyệt hoạt động. Tài khoản của bạn đã được nâng cấp thành Quản lý quán.',
        type: NotificationType.shopApproval,
        targetShopId: approved.id,
        createdAt: DateTime.now(),
      ),
    );

    return Result.success(approved);
  }

  @override
  Future<Result<void>> deleteShopByAdmin(String shopId) async {
    try {
      await remote.deleteShopByAdmin(shopId);
      db.shops.removeWhere((s) => s.id == shopId);
      return Result.success(null);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(_extractDioError(e, 'Không thể xoá quán')),
        );
      }
    } catch (_) {}

    final sIdx = db.shops.indexWhere((s) => s.id == shopId);
    if (sIdx != -1) {
      final removed = db.shops.removeAt(sIdx);
      final uIdx = db.users.indexWhere((u) => u.id == removed.ownerId);
      if (uIdx != -1 && db.users[uIdx].role == UserRole.manager) {
        db.users[uIdx] = db.users[uIdx].copyWith(role: UserRole.user);
      }
      db.notifications.insert(
        0,
        AppNotificationEntity(
          id: 'notif_del_${DateTime.now().millisecondsSinceEpoch}',
          userId: removed.ownerId,
          title: removed.isActive
              ? 'Quán "${removed.name}" đã bị xoá khỏi hệ thống'
              : 'Yêu cầu mở quán "${removed.name}" đã bị từ chối',
          body: removed.isActive
              ? 'Admin hệ thống đã gỡ quán "${removed.name}".'
              : 'Yêu cầu đăng ký mở quán "${removed.name}" chưa được Admin phê duyệt.',
          type: NotificationType.shopApproval,
          createdAt: DateTime.now(),
        ),
      );
    }
    return Result.success(null);
  }
}
