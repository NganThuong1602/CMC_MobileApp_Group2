import '../../core/enums/app_enums.dart';
import '../../core/utils/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Result<String>> requestRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  });

  Future<Result<UserEntity>> verifyRegisterOtpAndCreate({
    required String email,
    required String otpCode,
  });

  Future<Result<String>> requestForgotPasswordOtp({
    required String email,
  });

  Future<Result<void>> resetPasswordWithOtp({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  });

  Future<Result<UserEntity?>> getCurrentUser();

  Future<Result<UserEntity>> updateProfile({
    required String userId,
    required String fullName,
    DateTime? birthDate,
    Gender? gender,
    String? avatarUrl,
    String? coverUrl,
  });

  Future<Result<void>> logout();
}

