import 'package:equatable/equatable.dart';
import '../../core/enums/app_enums.dart';

class ShopEntity extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String phone;
  final String description;
  final String coverImageUrl;
  final List<String> galleryUrls;
  final double latitude;
  final double longitude;
  final String openTime;
  final String closeTime;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final DateTime? highlightExpiresAt;
  final bool isActive;
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final ShopPackagePlan? subscriptionPlan;
  final bool isCooperation;
  final DateTime? subscriptionExpiresAt;
  final bool serverIsHighlighted;
  final int activeDiscountPercent;
  final String activeDiscountName;
  final String activeDiscountCode;
  final String paymentCode;
  final int paymentAmount;
  final DateTime? paidAt;

  const ShopEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.description,
    required this.coverImageUrl,
    required this.galleryUrls,
    required this.latitude,
    required this.longitude,
    required this.openTime,
    required this.closeTime,
    required this.rating,
    required this.reviewCount,
    this.distanceKm = 0.0,
    this.highlightExpiresAt,
    this.isActive = true,
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.subscriptionPlan,
    this.isCooperation = false,
    this.subscriptionExpiresAt,
    this.serverIsHighlighted = false,
    this.activeDiscountPercent = 0,
    this.activeDiscountName = '',
    this.activeDiscountCode = '',
    this.paymentCode = '',
    this.paymentAmount = 0,
    this.paidAt,
  });

  bool get hasRating => reviewCount > 0 && rating > 0;

  bool isHighlightedAt(DateTime now) {
    return isCooperation ||
        serverIsHighlighted ||
        (highlightExpiresAt != null && highlightExpiresAt!.isAfter(now));
  }

  int discountedPriceOf(int originalPrice) {
    if (activeDiscountPercent <= 0) return originalPrice;
    return ((originalPrice * (100 - activeDiscountPercent)) / 100)
        .round()
        .clamp(0, originalPrice);
  }

  ShopEntity copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? address,
    String? phone,
    String? description,
    String? coverImageUrl,
    List<String>? galleryUrls,
    double? latitude,
    double? longitude,
    String? openTime,
    String? closeTime,
    double? rating,
    int? reviewCount,
    double? distanceKm,
    DateTime? highlightExpiresAt,
    bool? isActive,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    ShopPackagePlan? subscriptionPlan,
    bool? isCooperation,
    DateTime? subscriptionExpiresAt,
    bool? serverIsHighlighted,
    int? activeDiscountPercent,
    String? activeDiscountName,
    String? activeDiscountCode,
    String? paymentCode,
    int? paymentAmount,
    DateTime? paidAt,
  }) {
    return ShopEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      highlightExpiresAt: highlightExpiresAt ?? this.highlightExpiresAt,
      isActive: isActive ?? this.isActive,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      isCooperation: isCooperation ?? this.isCooperation,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      serverIsHighlighted: serverIsHighlighted ?? this.serverIsHighlighted,
      activeDiscountPercent:
          activeDiscountPercent ?? this.activeDiscountPercent,
      activeDiscountName: activeDiscountName ?? this.activeDiscountName,
      activeDiscountCode: activeDiscountCode ?? this.activeDiscountCode,
      paymentCode: paymentCode ?? this.paymentCode,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        address,
        phone,
        description,
        coverImageUrl,
        galleryUrls,
        latitude,
        longitude,
        openTime,
        closeTime,
        rating,
        reviewCount,
        distanceKm,
        highlightExpiresAt,
        isActive,
        ownerName,
        ownerPhone,
        ownerEmail,
        subscriptionPlan,
        isCooperation,
        subscriptionExpiresAt,
        serverIsHighlighted,
        activeDiscountPercent,
        activeDiscountName,
        activeDiscountCode,
        paymentCode,
        paymentAmount,
        paidAt,
      ];
}
