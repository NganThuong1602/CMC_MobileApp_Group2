import '../../core/enums/app_enums.dart';
import '../../core/utils/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  const LoginUseCase(this.repository);

  Future<Result<UserEntity>> call({
    required String email,
    required String password,
  }) {
    return repository.login(email: email, password: password);
  }
}

class RequestRegisterOtpUseCase {
  final AuthRepository repository;
  const RequestRegisterOtpUseCase(this.repository);

  Future<Result<String>> call({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    return repository.requestRegisterOtp(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
  }
}

class VerifyRegisterOtpUseCase {
  final AuthRepository repository;
  const VerifyRegisterOtpUseCase(this.repository);

  Future<Result<UserEntity>> call({
    required String email,
    required String otpCode,
  }) {
    return repository.verifyRegisterOtpAndCreate(
      email: email,
      otpCode: otpCode,
    );
  }
}

class UpdateProfileUseCase {
  final AuthRepository repository;
  const UpdateProfileUseCase(this.repository);

  Future<Result<UserEntity>> call({
    required String userId,
    required String fullName,
    DateTime? birthDate,
    Gender? gender,
    String? avatarUrl,
    String? coverUrl,
  }) {
    return repository.updateProfile(
      userId: userId,
      fullName: fullName,
      birthDate: birthDate,
      gender: gender,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
    );
  }
}

