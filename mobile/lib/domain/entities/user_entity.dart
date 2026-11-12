import 'package:equatable/equatable.dart';
import '../../core/enums/app_enums.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
  final String? coverUrl;
  final DateTime? birthDate;
  final Gender? gender;

  const UserEntity({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.coverUrl,
    this.birthDate,
    this.gender,
  });

  UserEntity copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? coverUrl,
    DateTime? birthDate,
    Gender? gender,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        fullName,
        role,
        avatarUrl,
        coverUrl,
        birthDate,
        gender,
      ];
}

