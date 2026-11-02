import 'package:equatable/equatable.dart';

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
  });

  bool isHighlightedAt(DateTime now) {
    return highlightExpiresAt != null && highlightExpiresAt!.isAfter(now);
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
      ];
}

