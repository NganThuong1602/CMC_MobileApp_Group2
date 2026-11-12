import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../../domain/entities/payment_transaction_entity.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/entities/time_slot_entity.dart';
import '../../../domain/entities/user_entity.dart';

class PendingRegisterDraft {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String otpCode;

  const PendingRegisterDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.otpCode,
  });
}

class PendingShopDraft {
  final String userId;
  final String name;
  final String address;
  final String phone;
  final String description;
  final String openTime;
  final String closeTime;
  final double latitude;
  final double longitude;
  final String coverImageUrl;

  const PendingShopDraft({
    required this.userId,
    required this.name,
    required this.address,
    required this.phone,
    required this.description,
    required this.openTime,
    required this.closeTime,
    required this.latitude,
    required this.longitude,
    required this.coverImageUrl,
  });
}

class InMemoryDatabase {
  final List<UserEntity> users = [];
  final Map<String, String> passwordsByEmail = {};
  final Map<String, PendingRegisterDraft> registerDraftsByEmail = {};
  final Map<String, String> resetOtpByEmail = {};

  final List<ShopEntity> shops = [];
  final List<ServiceEntity> services = [];
  final List<BarberEntity> barbers = [];
  final List<BookingEntity> bookings = [];
  final List<SlotLockEntity> slotLocks = [];

  final List<PostEntity> posts = [];
  final List<ReviewEntity> reviews = [];
  final List<ChatRoomEntity> chatRooms = [];
  final List<AppNotificationEntity> notifications = [];

  final List<PaymentTransactionEntity> transactions = [];
  final Map<String, PendingShopDraft> pendingShopDraftsByPaymentCode = {};
  final Map<String, ({String shopId, HighlightPackageType packageType})>
      pendingHighlightByPaymentCode = {};
  final Map<String, String> pendingBookingIdByPaymentCode = {};
  final Map<String, ({String shopId, int baseSalary})>
      pendingInvitePayloadByNotifId = {};

  UserEntity? currentUser;

  InMemoryDatabase() {
    _seedInitialData();
  }

  String buildVietQrUrl({
    required int amount,
    required String transferContent,
  }) {
    final encodedInfo = Uri.encodeComponent(transferContent);
    return 'https://qr.sepay.vn/img?bank=${AppConstants.sepayBankCode}&acc=${AppConstants.platformBankAccount}&template=compact&amount=$amount&des=$encodedInfo';
  }

  double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  void _seedInitialData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Seed Users cho đủ 4 Role (User, Manager, Barber, Admin) + tài khoản rảnh để test mời Barber
    const adminUser = UserEntity(
      id: 'u_admin_1',
      email: 'admin@barbersmart.vn',
      phone: '0900999999',
      fullName: 'Quản Trị Viên Hệ Thống',
      role: UserRole.admin,
      avatarUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
      gender: Gender.male,
    );
    users.add(adminUser.copyWith(birthDate: DateTime(1990, 1, 1)));
    passwordsByEmail['admin@barbersmart.vn'] = '123456';

    const customerUser = UserEntity(
      id: 'u_customer_1',
      email: 'user@barbersmart.vn',
      phone: '0908123456',
      fullName: 'Nguyễn Tuấn Anh',
      role: UserRole.user,
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
      birthDate: null,
      gender: Gender.male,
    );
    users.add(customerUser.copyWith(birthDate: DateTime(1996, 8, 15)));
    passwordsByEmail['user@barbersmart.vn'] = '123456';

    const managerUser = UserEntity(
      id: 'u_manager_1',
      email: 'manager@barbersmart.vn',
      phone: '0901888234',
      fullName: 'Trần Minh Quân',
      role: UserRole.manager,
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
      gender: Gender.male,
    );
    users.add(managerUser.copyWith(birthDate: DateTime(1992, 4, 20)));
    passwordsByEmail['manager@barbersmart.vn'] = '123456';

    const managerUser2 = UserEntity(
      id: 'u_manager_2',
      email: 'liem@barbersmart.vn',
      phone: '0901345678',
      fullName: 'Lê Thanh Liêm',
      role: UserRole.manager,
      gender: Gender.male,
    );
    users.add(managerUser2);
    passwordsByEmail['liem@barbersmart.vn'] = '123456';

    const managerUser3 = UserEntity(
      id: 'u_manager_3',
      email: 'classic@barbersmart.vn',
      phone: '0901999111',
      fullName: 'Hoàng Gia Bảo',
      role: UserRole.manager,
      gender: Gender.male,
    );
    users.add(managerUser3);
    passwordsByEmail['classic@barbersmart.vn'] = '123456';

    const barberUser1 = UserEntity(
      id: 'u_barber_1',
      email: 'barber@barbersmart.vn',
      phone: '0933111222',
      fullName: 'Lê Hoàng Phúc',
      role: UserRole.barber,
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80',
      coverUrl:
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
      gender: Gender.male,
    );
    users.add(barberUser1.copyWith(birthDate: DateTime(1997, 11, 10)));
    passwordsByEmail['barber@barbersmart.vn'] = '123456';

    const barberUser2 = UserEntity(
      id: 'u_barber_2',
      email: 'barber2@barbersmart.vn',
      phone: '0933444555',
      fullName: 'Đặng Quốc Khánh',
      role: UserRole.barber,
      avatarUrl:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&q=80',
      gender: Gender.male,
    );
    users.add(barberUser2);
    passwordsByEmail['barber2@barbersmart.vn'] = '123456';

    const barberOtherShop = UserEntity(
      id: 'u_barber_other',
      email: 'otherbarber@barbersmart.vn',
      phone: '0977888999',
      fullName: 'Võ Thành Đạt',
      role: UserRole.barber,
      gender: Gender.male,
    );
    users.add(barberOtherShop);
    passwordsByEmail['otherbarber@barbersmart.vn'] = '123456';

    const freeCandidate = UserEntity(
      id: 'u_free_1',
      email: 'newbarber@barbersmart.vn',
      phone: '0912345678',
      fullName: 'Phạm Gia Huy',
      role: UserRole.user,
      avatarUrl: AppConstants.defaultAvatarUrl,
      gender: Gender.male,
    );
    users.add(freeCandidate);
    passwordsByEmail['newbarber@barbersmart.vn'] = '123456';

    // 2. Seed Shops khu vực Vạn Phúc, Hà Đông, Hà Nội (cụm tọa độ ~20.976xxx, 105.772xxx)
    shops.addAll([
      ShopEntity(
        id: 'shop_1',
        ownerId: 'u_manager_1',
        name: 'Vạn Phúc Barber House',
        address: 'Số 48 Phố Lụa, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
        phone: '0901 888 234',
        description:
            'Không gian cắt tóc nam lịch lãm ngay Phố Lụa Vạn Phúc, Hà Đông. Dịch vụ tạo kiểu tóc, cạo râu truyền thống và thư giãn chuẩn phong cách quý ông.',
        coverImageUrl:
            'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
        galleryUrls: const [
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=600&q=80',
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=600&q=80',
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=600&q=80',
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=600&q=80',
        ],
        latitude: 20.9768,
        longitude: 105.7724,
        openTime: '08:30',
        closeTime: '20:30',
        rating: 4.9,
        reviewCount: 146,
        distanceKm: 0.2,
        highlightExpiresAt: now.add(const Duration(days: 100)),
      ),
      ShopEntity(
        id: 'shop_2',
        ownerId: 'u_manager_2',
        name: 'The Gentlemen Hair Salon Hà Đông',
        address: 'Số 126 Tố Hữu, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
        phone: '0902 888 111',
        description:
            'Không gian sang trọng mặt đường Tố Hữu - Vạn Phúc, chuyên fade sắc nét và tạo kiểu cổ điển.',
        coverImageUrl:
            'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        galleryUrls: const [
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=600&q=80',
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=600&q=80',
        ],
        latitude: 20.9785,
        longitude: 105.7746,
        openTime: '08:30',
        closeTime: '20:30',
        rating: 4.9,
        reviewCount: 112,
        distanceKm: 0.4,
        highlightExpiresAt: now.add(const Duration(days: 100)),
      ),
      ShopEntity(
        id: 'shop_3',
        ownerId: 'u_manager_3',
        name: '30Shine Studio Vạn Phúc',
        address: 'Số 82 Đường Vạn Phúc, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
        phone: '0903 888 222',
        description:
            'Tổ hợp cắt gội massage đá nóng và chăm sóc da mặt chuyên sâu tại Vạn Phúc, Hà Đông.',
        coverImageUrl:
            'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
        galleryUrls: const [
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=600&q=80',
        ],
        latitude: 20.9749,
        longitude: 105.7708,
        openTime: '08:30',
        closeTime: '21:00',
        rating: 4.8,
        reviewCount: 205,
        distanceKm: 0.5,
        highlightExpiresAt: now.add(const Duration(days: 100)),
      ),
    ]);

    // 3. Seed Services cho các quán
    services.addAll(const [
      ServiceEntity(
        id: 'srv_1',
        shopId: 'shop_1',
        name: 'Cắt tạo kiểu Quý ông (Fade / Side Part)',
        price: 100000,
        durationMinutes: 30,
      ),
      ServiceEntity(
        id: 'srv_2',
        shopId: 'shop_1',
        name: 'Gội đầu dưỡng sinh & Massage cổ vai gáy',
        price: 70000,
        durationMinutes: 20,
      ),
      ServiceEntity(
        id: 'srv_3',
        shopId: 'shop_1',
        name: 'Cạo mặt khăn nóng & Đắp mặt nạ',
        price: 60000,
        durationMinutes: 25,
      ),
      ServiceEntity(
        id: 'srv_4',
        shopId: 'shop_1',
        name: 'Uốn Premlock / Layer Hàn Quốc',
        price: 350000,
        durationMinutes: 60,
      ),
      ServiceEntity(
        id: 'srv_5',
        shopId: 'shop_2',
        name: 'Combo Cắt Chicano + Cạo khăn nóng',
        price: 120000,
        durationMinutes: 45,
      ),
      ServiceEntity(
        id: 'srv_6',
        shopId: 'shop_2',
        name: 'Tẩy & Nhuộm thời trang',
        price: 280000,
        durationMinutes: 60,
      ),
      ServiceEntity(
        id: 'srv_7',
        shopId: 'shop_3',
        name: 'Signature Gentleman Cut & Wash',
        price: 150000,
        durationMinutes: 45,
      ),
    ]);

    // 4. Seed Barbers
    final defaultJoinedAt = DateTime.now().subtract(const Duration(days: 30));
    barbers.addAll([
      BarberEntity(
        id: 'barber_1',
        userId: 'u_barber_1',
        shopId: 'shop_1',
        fullName: 'Lê Hoàng Phúc',
        email: 'barber@barbersmart.vn',
        phone: '0933111222',
        avatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&q=80',
        bio: 'Master Barber 6 năm kinh nghiệm Side Part & Skin Fade',
        rating: 4.9,
        baseSalary: 7000000,
        isActive: true,
        joinedAt: defaultJoinedAt,
      ),
      BarberEntity(
        id: 'barber_2',
        userId: 'u_barber_2',
        shopId: 'shop_1',
        fullName: 'Đặng Quốc Khánh',
        email: 'barber2@barbersmart.vn',
        phone: '0933444555',
        avatarUrl:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&q=80',
        bio: 'Chuyên uốn Layer, Mohican & phục hồi tóc hư tổn',
        rating: 4.8,
        baseSalary: 6500000,
        isActive: true,
        joinedAt: defaultJoinedAt,
      ),
      BarberEntity(
        id: 'barber_3',
        userId: 'u_barber_other',
        shopId: 'shop_2',
        fullName: 'Võ Thành Đạt',
        email: 'otherbarber@barbersmart.vn',
        phone: '0977888999',
        bio: 'Senior Chicano Fade Artist',
        rating: 4.9,
        baseSalary: 7500000,
        isActive: true,
        joinedAt: defaultJoinedAt,
      ),
    ]);

    // 5. Seed Bookings hôm nay để thấy rõ:
    // - Slot xám đã đặt (09:00 - 09:45) & chặn tràn giờ trước 11:30
    // - Lịch CONFIRMED chưa thanh toán (Barber có thể bấm "Xác nhận đã thanh toán", Khách có thể "Hủy lịch")
    // - Lịch COMPLETED (được tính doanh thu quán & 10% hoa hồng Barber)
    bookings.addAll([
      BookingEntity(
        id: 'bk_completed_1',
        shopId: 'shop_1',
        shopName: 'Vũ Trí Barber Shop - Chi nhánh 1',
        barberId: 'barber_1',
        barberName: 'Lê Hoàng Phúc',
        customerId: 'u_customer_1',
        customerName: 'Nguyễn Tuấn Anh',
        customerPhone: '0908123456',
        services: [services[0], services[1]],
        date: today,
        startMinutes: 9 * 60, // 09:00
        endMinutes: 9 * 60 + 50, // 09:50
        totalPrice: 170000,
        totalDurationMinutes: 50,
        paymentMethod: PaymentMethod.qrCode,
        status: BookingStatus.completed,
        isPaid: true,
        paymentCode: 'PAYBOOKING1001',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      BookingEntity(
        id: 'bk_confirmed_1',
        shopId: 'shop_1',
        shopName: 'Vũ Trí Barber Shop - Chi nhánh 1',
        barberId: 'barber_1',
        barberName: 'Lê Hoàng Phúc',
        customerId: 'u_customer_1',
        customerName: 'Nguyễn Tuấn Anh',
        customerPhone: '0908123456',
        services: [services[0]],
        date: today,
        startMinutes: 15 * 60, // 15:00
        endMinutes: 15 * 60 + 30, // 15:30
        totalPrice: 100000,
        totalDurationMinutes: 30,
        paymentMethod: PaymentMethod.atShop,
        status: BookingStatus.confirmed,
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      BookingEntity(
        id: 'bk_completed_2',
        shopId: 'shop_1',
        shopName: 'Vũ Trí Barber Shop - Chi nhánh 1',
        barberId: 'barber_2',
        barberName: 'Đặng Quốc Khánh',
        customerId: 'u_free_1',
        customerName: 'Phạm Gia Huy',
        customerPhone: '0912345678',
        services: [services[3]],
        date: today.subtract(const Duration(days: 1)),
        startMinutes: 14 * 60 + 30,
        endMinutes: 15 * 60 + 30,
        totalPrice: 350000,
        totalDurationMinutes: 60,
        paymentMethod: PaymentMethod.atShop,
        status: BookingStatus.completed,
        isPaid: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    // 6. Seed Bài viết Mạng xã hội chuẩn Ảnh 8 (Grid 5 ảnh)
    posts.add(
      PostEntity(
        id: 'post_1',
        authorId: 'u_customer_1',
        authorName: 'Nguyễn Tuấn Anh',
        authorRole: UserRole.user,
        authorAvatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&q=80',
        content:
            'Vừa làm kiểu Side Part Pompadour tại Vũ Trí Barber, thợ cắt rất ưng ý và tỉ mỉ!',
        imageUrls: const [
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=600&q=80',
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=600&q=80',
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=600&q=80',
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=600&q=80',
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=600&q=80',
        ],
        comments: [
          PostCommentEntity(
            id: 'cmt_1',
            postId: 'post_1',
            authorId: 'u_barber_1',
            authorName: 'Lê Hoàng Phúc',
            authorRole: UserRole.barber,
            content: 'Cảm ơn anh Tuấn Anh đã ghé ủng hộ shop ạ!',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    );

    // 7. Seed Reviews, Group Chat & Notifications
    reviews.addAll([
      ReviewEntity(
        id: 'rev_1',
        shopId: 'shop_1',
        userId: 'u_customer_1',
        userName: 'Nguyễn Tuấn Anh',
        rating: 5,
        comment: 'Fade siêu mượt, không gian máy lạnh sạch sẽ, đúng giờ!',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ReviewEntity(
        id: 'rev_2',
        shopId: 'shop_1',
        userId: 'u_free_1',
        userName: 'Phạm Gia Huy',
        rating: 5,
        comment: 'Đặt lịch trên app đến là cắt liền không phải đợi.',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ]);

    chatRooms.add(
      ChatRoomEntity(
        id: 'room_shop1_u1',
        shopId: 'shop_1',
        shopName: 'Vũ Trí Barber Shop - Chi nhánh 1',
        customerId: 'u_customer_1',
        customerName: 'Nguyễn Tuấn Anh',
        messages: [
          ChatMessageEntity(
            id: 'msg_1',
            roomId: 'room_shop1_u1',
            senderId: 'u_customer_1',
            senderName: 'Nguyễn Tuấn Anh',
            senderRole: UserRole.user,
            content: 'Chào shop, mặt mình hơi tròn thì hợp kiểu Side Part nào?',
            createdAt: now.subtract(const Duration(minutes: 25)),
          ),
          ChatMessageEntity(
            id: 'msg_2',
            roomId: 'room_shop1_u1',
            senderId: 'u_barber_1',
            senderName: 'Lê Hoàng Phúc',
            senderRole: UserRole.barber,
            content:
                'Chào bạn! Mặt tròn để Side Part 7/3 vuốt rủ nhẹ kèm taper fade hai bên sẽ cực kỳ thon gọn nhé.',
            createdAt: now.subtract(const Duration(minutes: 22)),
          ),
        ],
      ),
    );

    notifications.addAll([
      AppNotificationEntity(
        id: 'notif_1',
        userId: 'u_customer_1',
        title: 'Đặt lịch thành công',
        body:
            'Lịch hẹn 15:00 hôm nay cùng Barber Lê Hoàng Phúc tại Vũ Trí Barber Shop đã được xác nhận.',
        type: NotificationType.bookingCreated,
        isRead: false,
        targetShopId: 'shop_1',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      AppNotificationEntity(
        id: 'notif_2',
        userId: 'u_customer_1',
        title: 'SePay đã xác nhận thanh toán QR',
        body: 'Giao dịch 170.000đ cho lịch 09:00 đã tự động hoàn tất.',
        type: NotificationType.paymentConfirmed,
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AppNotificationEntity(
        id: 'notif_3',
        userId: 'u_customer_1',
        title: 'Ưu đãi Thành viên thân thiết',
        body: 'Giảm 15% combo uốn nhuộm trong tuần lễ vàng tại Vũ Trí Barber.',
        type: NotificationType.system,
        isRead: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppNotificationEntity(
        id: 'notif_mgr_1',
        userId: 'u_manager_1',
        title: 'Khách hàng mới đặt lịch',
        body: 'Nguyễn Tuấn Anh vừa đặt lịch lúc 15:00 hôm nay.',
        type: NotificationType.bookingCreated,
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      AppNotificationEntity(
        id: 'notif_barber_1',
        userId: 'u_barber_1',
        title: 'Lịch cắt mới lúc 15:00',
        body: 'Khách Nguyễn Tuấn Anh đặt Cắt tạo kiểu Quý ông (30 phút).',
        type: NotificationType.bookingCreated,
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ]);
  }
}

