import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/enums/app_enums.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;
  final bool isLoading;
  final String? pendingOtpEmail;
  final bool isForgotPasswordFlow;
  final String? errorMessage;
  final String? infoMessage;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.isLoading = false,
    this.pendingOtpEmail,
    this.isForgotPasswordFlow = false,
    this.errorMessage,
    this.infoMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    bool clearUser = false,
    bool? isLoading,
    String? pendingOtpEmail,
    bool clearPendingOtp = false,
    bool? isForgotPasswordFlow,
    String? errorMessage,
    String? infoMessage,
  }) {
    final resolvedUser = clearUser ? null : (user ?? this.user);
    final resolvedStatus = status ??
        (resolvedUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated);
    return AuthState(
      status: resolvedStatus,
      user: resolvedUser,
      isLoading: isLoading ?? this.isLoading,
      pendingOtpEmail:
          clearPendingOtp ? null : (pendingOtpEmail ?? this.pendingOtpEmail),
      isForgotPasswordFlow: isForgotPasswordFlow ?? this.isForgotPasswordFlow,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        isLoading,
        pendingOtpEmail,
        isForgotPasswordFlow,
        errorMessage,
        infoMessage,
      ];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  final ValueNotifier<UserEntity?> authListenable = ValueNotifier(null);

  AuthCubit({required this.authRepository}) : super(const AuthState());

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.login(email: email, password: password);
    res.fold(
      onFailure: (f) => emit(
        state.copyWith(isLoading: false, errorMessage: f.message),
      ),
      onSuccess: (user) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
            clearPendingOtp: true,
          ),
        );
        authListenable.value = user;
      },
    );
  }

  Future<void> requestRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.requestRegisterOtp(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
    res.fold(
      onFailure: (f) => emit(
        state.copyWith(isLoading: false, errorMessage: f.message),
      ),
      onSuccess: (msg) => emit(
        state.copyWith(
          isLoading: false,
          pendingOtpEmail: email.trim().toLowerCase(),
          isForgotPasswordFlow: false,
          infoMessage: msg,
        ),
      ),
    );
  }

  Future<void> verifyRegisterOtp(String otpCode) async {
    final email = state.pendingOtpEmail;
    if (email == null) return;
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.verifyRegisterOtpAndCreate(
      email: email,
      otpCode: otpCode,
    );
    res.fold(
      onFailure: (f) => emit(
        state.copyWith(isLoading: false, errorMessage: f.message),
      ),
      onSuccess: (user) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
            clearPendingOtp: true,
            infoMessage: 'Đăng ký tài khoản thành công!',
          ),
        );
        authListenable.value = user;
      },
    );
  }

  Future<void> requestForgotPasswordOtp(String email) async {
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.requestForgotPasswordOtp(email: email);
    res.fold(
      onFailure: (f) => emit(
        state.copyWith(isLoading: false, errorMessage: f.message),
      ),
      onSuccess: (msg) => emit(
        state.copyWith(
          isLoading: false,
          pendingOtpEmail: email.trim().toLowerCase(),
          isForgotPasswordFlow: true,
          infoMessage: msg,
        ),
      ),
    );
  }

  Future<bool> resetPassword({
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final email = state.pendingOtpEmail;
    if (email == null) return false;
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.resetPasswordWithOtp(
      email: email,
      otpCode: otpCode,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    return res.fold(
      onFailure: (f) {
        emit(state.copyWith(isLoading: false, errorMessage: f.message));
        return false;
      },
      onSuccess: (_) {
        emit(
          state.copyWith(
            isLoading: false,
            clearPendingOtp: true,
            isForgotPasswordFlow: false,
            infoMessage: 'Đổi mật khẩu thành công! Vui lòng đăng nhập lại.',
          ),
        );
        return true;
      },
    );
  }

  void cancelOtpStep() {
    emit(
      state.copyWith(
        clearPendingOtp: true,
        isForgotPasswordFlow: false,
      ),
    );
  }

  Future<void> refreshCurrentUser() async {
    final res = await authRepository.getCurrentUser();
    res.fold(
      onFailure: (_) {},
      onSuccess: (user) {
        if (user != null) {
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              user: user,
            ),
          );
          authListenable.value = user;
        }
      },
    );
  }

  Future<void> updateProfile({
    required String fullName,
    DateTime? birthDate,
    Gender? gender,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    final current = state.user;
    if (current == null) return;
    emit(state.copyWith(isLoading: true));
    final res = await authRepository.updateProfile(
      userId: current.id,
      fullName: fullName,
      birthDate: birthDate,
      gender: gender,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
    );
    res.fold(
      onFailure: (f) =>
          emit(state.copyWith(isLoading: false, errorMessage: f.message)),
      onSuccess: (updated) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: updated,
            isLoading: false,
            infoMessage: 'Đã cập nhật hồ sơ cá nhân',
          ),
        );
        authListenable.value = updated;
      },
    );
  }

  /// Đăng xuất chuẩn:
  /// 1. Xoá sạch Token/Session cục bộ & đóng kết nối Socket.
  /// 2. Emit state Unauthenticated TRƯỚC để GoRouter lắng nghe stream và redirect thẳng về `/login`.
  Future<void> logout() async {
    await authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
    authListenable.value = null;
  }
}
