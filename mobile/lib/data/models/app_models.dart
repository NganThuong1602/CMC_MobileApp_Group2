import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../domain/entities/barber_entity.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/payment_transaction_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/shop_entity.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.phone,
    required super.fullName,
    required super.role,
    super.avatarUrl,
    super.coverUrl,
    super.birthDate,
    super.gender,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    Gender? parsedGender;
    final rawGender = (json['gender'] ?? '').toString().toUpperCase();
    if (rawGender == 'MALE' || rawGender == 'NAM') {
      parsedGender = Gender.male;
    } else if (rawGender == 'FEMALE' || rawGender == 'NU') {
      parsedGender = Gender.female;
    } else if (rawGender.isNotEmpty) {
      parsedGender = Gender.other;
    }

    final rawAvatar = json['avatarUrl']?.toString().trim();
    final rawCover = json['coverUrl']?.toString().trim();

    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      role: UserRole.fromApi(json['role']?.toString()),
      avatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty)
          ? rawAvatar
          : AppConstants.defaultAvatarUrl,
      coverUrl: (rawCover != null && rawCover.isNotEmpty) ? rawCover : null,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'].toString())
          : null,
      gender: parsedGender,
    );
  }
}

class ShopModel extends ShopEntity {
  const ShopModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.address,
    required super.phone,
    required super.description,
    required super.coverImageUrl,
    required super.galleryUrls,
    required super.latitude,
    required super.longitude,
    required super.openTime,
    required super.closeTime,
    required super.rating,
    required super.reviewCount,
    super.distanceKm,
    super.highlightExpiresAt,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    final gallery = (json['galleryUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final cover =
        (json['coverUrl'] ?? json['coverImageUrl'] ?? json['avatarUrl'] ?? '')
            .toString();
    return ShopModel(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      coverImageUrl: cover.isNotEmpty
          ? cover
          : 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
      galleryUrls: gallery,
      latitude:
          (json['latitude'] as num?)?.toDouble() ?? AppConstants.defaultLat,
      longitude:
          (json['longitude'] as num?)?.toDouble() ?? AppConstants.defaultLng,
      openTime: (json['openTime'] ?? '08:30').toString(),
      closeTime: (json['closeTime'] ?? '20:30').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.5,
      highlightExpiresAt: json['highlightExpiresAt'] != null
          ? DateTime.tryParse(json['highlightExpiresAt'].toString())
          : null,
    );
  }
}

class ServiceModel extends ServiceEntity {
  const ServiceModel({
    required super.id,
    required super.shopId,
    required super.name,
    required super.price,
    required super.durationMinutes,
    super.imageUrl,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: (json['id'] ?? '').toString(),
      shopId: (json['shopId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class BarberModel extends BarberEntity {
  const BarberModel({
    required super.id,
    required super.userId,
    required super.shopId,
    required super.fullName,
    required super.email,
    required super.phone,
    super.avatarUrl,
    super.bio,
    super.rating,
    super.baseSalary,
    super.isActive,
    super.invitationAccepted,
  });

  factory BarberModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackShopId = '',
  }) {
    final userObj = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final rawAvatar =
        (json['avatarUrl'] ?? userObj?['avatarUrl'])?.toString().trim();
    return BarberModel(
      id: (json['id'] ?? json['barberId'] ?? '').toString(),
      userId: (json['userId'] ?? userObj?['id'] ?? '').toString(),
      shopId: (json['shopId'] ?? json['shop']?['id'] ?? fallbackShopId)
          .toString(),
      fullName:
          (json['fullName'] ?? userObj?['fullName'] ?? 'Barber').toString(),
      email: (json['email'] ?? userObj?['email'] ?? '').toString(),
      phone: (json['phone'] ?? userObj?['phone'] ?? '').toString(),
      avatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty)
          ? rawAvatar
          : AppConstants.defaultAvatarUrl,
      bio: (json['bio'] ?? 'Thợ cắt tóc chuyên nghiệp').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      baseSalary: (json['baseSalary'] as num?)?.toInt() ?? 6500000,
      isActive: json['isActive'] as bool? ?? true,
      invitationAccepted: json['invitationAccepted'] as bool? ?? true,
    );
  }
}

class PaymentTransactionModel extends PaymentTransactionEntity {
  const PaymentTransactionModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.amount,
    required super.paymentCode,
    required super.transferContent,
    required super.qrImageUrl,
    required super.status,
    super.referenceId,
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: (json['id'] ?? json['transactionId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      paymentCode: (json['paymentCode'] ?? '').toString(),
      transferContent: (json['transferContent'] ?? '').toString(),
      qrImageUrl: (json['qrImageUrl'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      referenceId:
          (json['referenceId'] ?? json['shopId'] ?? json['bookingId'])
              ?.toString(),
    );
  }
}

class BookingModel extends BookingEntity {
  const BookingModel({
    required super.id,
    required super.shopId,
    required super.shopName,
    required super.barberId,
    required super.barberName,
    required super.customerId,
    required super.customerName,
    required super.customerPhone,
    required super.services,
    required super.date,
    required super.startMinutes,
    required super.endMinutes,
    required super.totalPrice,
    required super.totalDurationMinutes,
    required super.paymentMethod,
    required super.status,
    required super.isPaid,
    super.paymentCode,
    required super.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'CONFIRMED').toString().toUpperCase();
    BookingStatus status;
    switch (rawStatus) {
      case 'PENDING_PAYMENT':
      case 'PENDING':
        status = BookingStatus.pending;
        break;
      case 'COMPLETED':
        status = BookingStatus.completed;
        break;
      case 'CANCELLED':
        status = BookingStatus.cancelled;
        break;
      default:
        status = BookingStatus.confirmed;
    }

    final rawMethod =
        (json['paymentMethod'] ?? 'CASH_AT_SHOP').toString().toUpperCase();
    final method = (rawMethod.contains('QR') || rawMethod.contains('SEPAY'))
        ? PaymentMethod.qrCode
        : PaymentMethod.atShop;

    final rawServices =
        (json['servicesSnapshot'] as List?) ?? (json['services'] as List?) ?? const [];
    final services = rawServices
        .whereType<Map>()
        .map((m) => ServiceModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final barberMap = json['barber'] is Map
        ? Map<String, dynamic>.from(json['barber'] as Map)
        : null;
    final barberUserMap = barberMap?['user'] is Map
        ? Map<String, dynamic>.from(barberMap!['user'] as Map)
        : null;

    return BookingModel(
      id: (json['id'] ?? '').toString(),
      shopId: (json['shopId'] ?? json['shop']?['id'] ?? '').toString(),
      shopName: (json['shopName'] ?? json['shop']?['name'] ?? '').toString(),
      barberId: (json['barberId'] ?? barberMap?['id'] ?? '').toString(),
      barberName: (json['barberName'] ??
              barberUserMap?['fullName'] ??
              barberMap?['fullName'] ??
              'Barber')
          .toString(),
      customerId: (json['customerId'] ?? '').toString(),
      customerName: (json['customerName'] ??
              json['customer']?['fullName'] ??
              'Khách hàng')
          .toString(),
      customerPhone:
          (json['customerPhone'] ?? json['customer']?['phone'] ?? '').toString(),
      services: services,
      date: DateTime.tryParse(
            (json['bookingDate'] ?? json['date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 510,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 555,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
      totalDurationMinutes:
          (json['totalDurationMinutes'] as num?)?.toInt() ?? 30,
      paymentMethod: method,
      status: status,
      isPaid: json['isPaid'] as bool? ?? false,
      paymentCode: json['paymentCode']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class PostCommentModel extends PostCommentEntity {
  const PostCommentModel({
    required super.id,
    required super.postId,
    required super.authorId,
    required super.authorName,
    required super.authorRole,
    super.authorAvatarUrl,
    required super.content,
    required super.createdAt,
  });

  factory PostCommentModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackPostId = '',
  }) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : null;
    final rawAvatar =
        (json['authorAvatarUrl'] ?? author?['avatarUrl'])?.toString().trim();
    return PostCommentModel(
      id: (json['id'] ?? '').toString(),
      postId: (json['postId'] ?? fallbackPostId).toString(),
      authorId: (json['authorId'] ?? author?['id'] ?? '').toString(),
      authorName:
          (json['authorName'] ?? author?['fullName'] ?? 'Thành viên').toString(),
      authorRole: UserRole.fromApi(
        (json['authorRole'] ?? author?['role'])?.toString(),
      ),
      authorAvatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty)
          ? rawAvatar
          : AppConstants.defaultAvatarUrl,
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class PostModel extends PostEntity {
  const PostModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    required super.authorRole,
    super.authorAvatarUrl,
    required super.content,
    required super.imageUrls,
    required super.comments,
    required super.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final postId = (json['id'] ?? '').toString();
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : null;
    final rawAvatar =
        (json['authorAvatarUrl'] ?? author?['avatarUrl'])?.toString().trim();
    final imgs = (json['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final cmts = (json['comments'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => PostCommentModel.fromJson(
                Map<String, dynamic>.from(m),
                fallbackPostId: postId,
              ),
            )
            .toList() ??
        const <PostCommentEntity>[];

    return PostModel(
      id: postId,
      authorId: (json['authorId'] ?? author?['id'] ?? '').toString(),
      authorName:
          (json['authorName'] ?? author?['fullName'] ?? 'Người dùng').toString(),
      authorRole: UserRole.fromApi(
        (json['authorRole'] ?? author?['role'])?.toString(),
      ),
      authorAvatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty)
          ? rawAvatar
          : AppConstants.defaultAvatarUrl,
      content: (json['caption'] ?? json['content'] ?? '').toString(),
      imageUrls: imgs,
      comments: cmts,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class ReviewModel extends ReviewEntity {
  const ReviewModel({
    required super.id,
    required super.shopId,
    required super.userId,
    required super.userName,
    super.userAvatarUrl,
    required super.rating,
    required super.comment,
    required super.createdAt,
  });

  factory ReviewModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackShopId = '',
  }) {
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : null;
    final rawAvatar = (json['customerAvatar'] ??
            json['userAvatarUrl'] ??
            customer?['avatarUrl'])
        ?.toString()
        .trim();
    return ReviewModel(
      id: (json['id'] ?? '').toString(),
      shopId: (json['shopId'] ?? fallbackShopId).toString(),
      userId:
          (json['customerId'] ?? json['userId'] ?? customer?['id'] ?? '')
              .toString(),
      userName: (json['customerName'] ??
              json['userName'] ??
              customer?['fullName'] ??
              'Khách hàng')
          .toString(),
      userAvatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty)
          ? rawAvatar
          : AppConstants.defaultAvatarUrl,
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: (json['comment'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class AppNotificationModel extends AppNotificationEntity {
  const AppNotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    super.isRead,
    super.targetShopId,
    super.targetBarberId,
    required super.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString().toUpperCase();
    NotificationType type = NotificationType.bookingCreated;
    if (rawType.contains('INVITE')) {
      type = NotificationType.barberInvitation;
    } else if (rawType.contains('PAYMENT')) {
      type = NotificationType.paymentConfirmed;
    }
    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;
    return AppNotificationModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['recipientId'] ?? json['userId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: type,
      isRead: json['isRead'] as bool? ?? false,
      targetShopId: meta?['shopId']?.toString(),
      targetBarberId: meta?['barberId']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
