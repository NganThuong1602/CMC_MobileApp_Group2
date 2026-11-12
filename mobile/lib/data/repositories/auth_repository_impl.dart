import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/network/socket_service.dart';
import '../../core/services/session_storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/in_memory_database.dart';
import '../datasources/remote/remote_api_datasource.dart';
import '../models/app_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  final InMemoryDatabase db;
  final RemoteApiDataSource remote;
  final SocketService socketService;
  final SessionStorageService sessionStorage;

  AuthRepositoryImpl({
    required this.db,
    required this.remote,
    required this.socketService,
    this.sessionStorage = const SessionStorageService(),
  }) {
    _restorePersistedSessionSync();
  }

  void _restorePersistedSessionSync() {
    try {
      final savedToken = sessionStorage.readToken();
      final savedUserRaw = sessionStorage.readUserJson();
      if (savedUserRaw != null && savedUserRaw.isNotEmpty) {
        final decoded = jsonDecode(savedUserRaw);
        if (decoded is Map) {
          final restoredUser = UserModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (restoredUser.id.isNotEmpty) {
            if (savedToken != null && savedToken.isNotEmpty) {
              remote.apiClient.setAccessToken(savedToken);
            }
            final idx = db.users.indexWhere((u) => u.id == restoredUser.id);
            if (idx == -1) {
              db.users.add(restoredUser);
            } else {
              db.users[idx] = restoredUser;
            }
            db.currentUser = restoredUser;
            socketService.connect(restoredUser.id);
          }
        }
      }
    } catch (_) {}
  }

  void _syncUserToLocalCache(UserEntity user, {String? token}) {
    final idx = db.users.indexWhere((u) => u.id == user.id);
    if (idx == -1) {
      db.users.add(user);
    } else {
      db.users[idx] = user;
    }
    db.currentUser = user;
    sessionStorage.saveSession(
      token: token ?? remote.apiClient.accessToken,
      userJson: jsonEncode(UserModel.toJson(user)),
    );
  }

  String _extractDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) {
        return msg.first.toString();
      }
      if (msg != null) return msg.toString();
    }
    return fallback;
  }

  @override
  Future<Result<UserEntity>> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng nhập đầy đủ Email và Mật khẩu'),
      );
    }

    try {
      final remoteRes = await remote.login(normalizedEmail, password);
      _syncUserToLocalCache(remoteRes.user, token: remoteRes.token);
      socketService.connect(remoteRes.user.id);
      return Result.success(remoteRes.user);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          AuthFailure(_extractDioError(e, 'Email hoặc mật khẩu không chính xác')),
        );
      }
      // Fallback sang dữ liệu Seeded Local khi chạy độc lập không bật server NestJS
    } catch (_) {}

    final storedPass = db.passwordsByEmail[normalizedEmail];
    final idx = db.users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (idx == -1 || storedPass != password) {
      return Result.failure(
        const AuthFailure('Email hoặc mật khẩu không chính xác'),
      );
    }

    final user = db.users[idx];
    _syncUserToLocalCache(user);
    socketService.connect(user.id);
    return Result.success(user);
  }

  @override
  Future<Result<String>> requestRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();

    if (cleanName.isEmpty ||
        cleanEmail.isEmpty ||
        cleanPhone.isEmpty ||
        password.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng điền đầy đủ thông tin bắt buộc (*)'),
      );
    }
    if (!cleanEmail.contains('@')) {
      return Result.failure(
        const ValidationFailure('Địa chỉ Email không hợp lệ'),
      );
    }
    final phoneErr = AppFormatters.validateVietnamPhone(cleanPhone);
    if (phoneErr != null) {
      return Result.failure(ValidationFailure(phoneErr));
    }
    if (password.length < 6) {
      return Result.failure(
        const ValidationFailure('Mật khẩu phải có tối thiểu 6 ký tự'),
      );
    }
    if (password != confirmPassword) {
      return Result.failure(
        const ValidationFailure('Xác nhận mật khẩu không trùng khớp'),
      );
    }

    try {
      final msg = await remote.requestRegisterOtp(
        fullName: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        password: password,
        confirmPassword: confirmPassword,
      );
      return Result.success(msg);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(_extractDioError(e, 'Email hoặc SĐT đã tồn tại')),
        );
      }
    } catch (_) {}

    if (db.users.any((u) => u.email.toLowerCase() == cleanEmail)) {
      return Result.failure(
        const ConflictFailure('Email này đã được sử dụng trên hệ thống'),
      );
    }
    if (db.users.any((u) => u.phone == cleanPhone)) {
      return Result.failure(
        const ConflictFailure('Số điện thoại này đã được đăng ký'),
      );
    }

    db.registerDraftsByEmail[cleanEmail] = PendingRegisterDraft(
      fullName: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      password: password,
      otpCode: AppConstants.demoOtpCode,
    );

    return Result.success(
      'Mã OTP 6 số đã được gửi tới $cleanEmail. Vui lòng kiểm tra hộp thư của bạn.',
    );
  }

  @override
  Future<Result<UserEntity>> verifyRegisterOtpAndCreate({
    required String email,
    required String otpCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otpCode.trim();

    try {
      final remoteRes = await remote.verifyRegisterOtp(cleanEmail, cleanOtp);
      _syncUserToLocalCache(remoteRes.user, token: remoteRes.token);
      socketService.connect(remoteRes.user.id);
      return Result.success(remoteRes.user);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          AuthFailure(
            _extractDioError(e, 'Mã OTP không chính xác hoặc đã hết hạn'),
          ),
        );
      }
    } catch (_) {}

    final draft = db.registerDraftsByEmail[cleanEmail];
    if (draft == null) {
      return Result.failure(
        const AuthFailure('Phiên xác thực OTP không tồn tại hoặc đã hết hạn'),
      );
    }
    if (draft.otpCode != cleanOtp) {
      return Result.failure(
        const AuthFailure('Mã OTP không chính xác hoặc đã hết hạn'),
      );
    }

    // Luôn khởi tạo Role mặc định là USER và Avatar xám mặc định
    final created = UserEntity(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      email: draft.email,
      phone: draft.phone,
      fullName: draft.fullName,
      role: UserRole.user,
      avatarUrl: AppConstants.defaultAvatarUrl,
      gender: Gender.male,
    );

    db.users.add(created);
    db.passwordsByEmail[cleanEmail] = draft.password;
    db.registerDraftsByEmail.remove(cleanEmail);
    _syncUserToLocalCache(created);
    socketService.connect(created.id);
    return Result.success(created);
  }

  @override
  Future<Result<String>> requestForgotPasswordOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final msg = await remote.requestForgotPasswordOtp(cleanEmail);
      return Result.success(msg);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không tìm thấy tài khoản với Email này'),
          ),
        );
      }
    } catch (_) {}

    final exists = db.users.any((u) => u.email.toLowerCase() == cleanEmail);
    if (!exists) {
      return Result.failure(
        const ValidationFailure('Không tìm thấy tài khoản với Email này'),
      );
    }
    db.resetOtpByEmail[cleanEmail] = AppConstants.demoOtpCode;
    return Result.success(
      'Đã gửi OTP khôi phục mật khẩu tới $cleanEmail. Vui lòng kiểm tra email của bạn.',
    );
  }

  @override
  Future<Result<void>> resetPasswordWithOtp({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 6) {
      return Result.failure(
        const ValidationFailure('Mật khẩu mới tối thiểu 6 ký tự'),
      );
    }
    if (newPassword != confirmPassword) {
      return Result.failure(
        const ValidationFailure('Xác nhận mật khẩu mới không khớp'),
      );
    }

    try {
      await remote.resetPassword(
        email: cleanEmail,
        otpCode: otpCode.trim(),
        newPassword: newPassword,
      );
      return Result.success(null);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          AuthFailure(
            _extractDioError(e, 'Mã OTP không hợp lệ hoặc đã hết hạn'),
          ),
        );
      }
    } catch (_) {}

    final expectedOtp = db.resetOtpByEmail[cleanEmail];
    if (expectedOtp == null || expectedOtp != otpCode.trim()) {
      return Result.failure(const AuthFailure('Mã OTP không hợp lệ'));
    }
    db.passwordsByEmail[cleanEmail] = newPassword;
    db.resetOtpByEmail.remove(cleanEmail);
    return Result.success(null);
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    if (db.currentUser == null) {
      return Result.success(null);
    }
    try {
      final freshUser = await remote.getMe();
      _syncUserToLocalCache(freshUser);
      return Result.success(freshUser);
    } catch (_) {
      final latestIdx = db.users.indexWhere((u) => u.id == db.currentUser!.id);
      if (latestIdx != -1) {
        db.currentUser = db.users[latestIdx];
      }
      return Result.success(db.currentUser);
    }
  }

  @override
  Future<Result<UserEntity>> updateProfile({
    required String userId,
    required String fullName,
    DateTime? birthDate,
    Gender? gender,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    try {
      final updatedRemote = await remote.updateProfile(
        fullName: fullName.trim().isEmpty ? null : fullName.trim(),
        birthDate: birthDate,
        gender: gender,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
      );
      _syncUserToLocalCache(updatedRemote);
      return Result.success(updatedRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể lưu cập nhật hồ sơ'),
          ),
        );
      }
    } catch (_) {}

    final idx = db.users.indexWhere((u) => u.id == userId);
    if (idx == -1) {
      return Result.failure(const AuthFailure('Không tìm thấy tài khoản'));
    }
    final updated = db.users[idx].copyWith(
      fullName:
          fullName.trim().isEmpty ? db.users[idx].fullName : fullName.trim(),
      birthDate: birthDate ?? db.users[idx].birthDate,
      gender: gender ?? db.users[idx].gender,
      avatarUrl: avatarUrl ?? db.users[idx].avatarUrl,
      coverUrl: coverUrl ?? db.users[idx].coverUrl,
    );
    db.users[idx] = updated;
    if (db.currentUser?.id == userId) {
      _syncUserToLocalCache(updated);
    }
    return Result.success(updated);
  }

  @override
  Future<Result<void>> logout() async {
    // Dọn dẹp sạch Token/Session cục bộ & đóng WebSocket
    remote.clearToken();
    db.currentUser = null;
    sessionStorage.clearSession();
    socketService.disconnect();
    return Result.success(null);
  }
}
