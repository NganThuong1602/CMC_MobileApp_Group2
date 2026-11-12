import 'package:equatable/equatable.dart';

class BarberEntity extends Equatable {
  final String id;
  final String userId;
  final String shopId;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String bio;
  final double rating;
  final int baseSalary;
  final bool isActive;
  final bool invitationAccepted;
  final DateTime? joinedAt;

  const BarberEntity({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.bio = 'Thợ cắt tóc chuyên nghiệp',
    this.rating = 4.9,
    this.baseSalary = 6000000,
    this.isActive = true,
    this.invitationAccepted = true,
    this.joinedAt,
  });

  BarberEntity copyWith({
    int? baseSalary,
    bool? isActive,
    bool? invitationAccepted,
  }) {
    return BarberEntity(
      id: id,
      userId: userId,
      shopId: shopId,
      fullName: fullName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      bio: bio,
      rating: rating,
      baseSalary: baseSalary ?? this.baseSalary,
      isActive: isActive ?? this.isActive,
      invitationAccepted: invitationAccepted ?? this.invitationAccepted,
      joinedAt: joinedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        shopId,
        fullName,
        email,
        phone,
        avatarUrl,
        bio,
        rating,
        baseSalary,
        isActive,
        invitationAccepted,
      ];
}

