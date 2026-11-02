import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Màn hình Xác thực chuẩn Pixel-perfect theo Ảnh 1 (Đăng nhập) & Ảnh 2 (Đăng ký)
/// kèm bước nhập mã OTP 6 số gửi qua Email (Nodemailer NestJS).
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoginTab = true;
  bool _obscureLoginPass = true;
  bool _obscureRegPass = true;
  bool _obscureRegConfirm = true;

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Register controllers (Chuẩn Ảnh 2: Họ tên, Email xác thực *, SĐT *, Mật khẩu *, Nhập lại mật khẩu *)
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  // OTP & Reset Password controllers
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _newPassConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _newPassConfirmCtrl.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _loginEmailCtrl.text.trim());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quên mật khẩu?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ Email đã đăng ký để nhận mã xác thực OTP 6 số:',
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline_rounded),
                hintText: 'Nhập địa chỉ email',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              Navigator.pop(ctx);
              context.read<AuthCubit>().requestForgotPasswordOtp(email);
            },
            child: const Text('Gửi OTP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go('/');
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        } else if (state.infoMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.infoMessage!),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _buildLogoHeader(),
                      const SizedBox(height: 24),
                      if (state.pendingOtpEmail != null)
                        _buildOtpVerificationCard(state)
                      else ...[
                        _buildSegmentedSwitcher(),
                        const SizedBox(height: 20),
                        if (_isLoginTab)
                          _buildLoginForm(state)
                        else
                          _buildRegisterForm(state),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreenLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.content_cut_rounded,
            color: AppTheme.primaryGreen,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isLoginTab ? AppTheme.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng nhập',
                  style: TextStyle(
                    color: _isLoginTab ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      !_isLoginTab ? AppTheme.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng ký',
                  style: TextStyle(
                    color: !_isLoginTab ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AuthState state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Email', requiredField: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  hintText: 'Nhập email',
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Mật khẩu', requiredField: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginPassCtrl,
                obscureText: _obscureLoginPass,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  hintText: 'Nhập mật khẩu',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureLoginPass = !_obscureLoginPass),
                    icon: Icon(
                      _obscureLoginPass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 28),
                  ),
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          context.read<AuthCubit>().login(
                                email: _loginEmailCtrl.text,
                                password: _loginPassCtrl.text,
                              );
                        },
                  child: Text(
                    state.isLoading ? 'Đang đăng nhập...' : 'Đăng nhập',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Họ tên', requiredField: false),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regNameCtrl,
          decoration: const InputDecoration(
            fillColor: AppTheme.surfaceWhite,
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            hintText: 'Nhập họ và tên',
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Email xác thực', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            fillColor: AppTheme.surfaceWhite,
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            hintText: 'Nhập địa chỉ email',
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Số điện thoại', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            fillColor: AppTheme.surfaceWhite,
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            hintText: 'Nhập số điện thoại',
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Mật khẩu', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regPassCtrl,
          obscureText: _obscureRegPass,
          decoration: InputDecoration(
            fillColor: AppTheme.surfaceWhite,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            hintText: 'Nhập mật khẩu',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureRegPass = !_obscureRegPass),
              icon: Icon(
                _obscureRegPass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Nhập lại mật khẩu', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regConfirmCtrl,
          obscureText: _obscureRegConfirm,
          decoration: InputDecoration(
            fillColor: AppTheme.surfaceWhite,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            hintText: 'Nhập lại mật khẩu',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureRegConfirm = !_obscureRegConfirm),
              icon: Icon(
                _obscureRegConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
              children: [
                TextSpan(text: 'Bằng việc bấm đăng ký, bạn đồng ý với '),
                TextSpan(
                  text: 'Điều khoản',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' và '),
                TextSpan(
                  text: 'Bảo mật',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' của Barbersmart.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () {
                    context.read<AuthCubit>().requestRegisterOtp(
                          fullName: _regNameCtrl.text,
                          email: _regEmailCtrl.text,
                          phone: _regPhoneCtrl.text,
                          password: _regPassCtrl.text,
                          confirmPassword: _regConfirmCtrl.text,
                        );
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.isLoading ? 'Đang gửi OTP...' : 'Đăng ký'),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpVerificationCard(AuthState state) {
    final isReset = state.isForgotPasswordFlow;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReset ? 'Khôi phục mật khẩu (OTP)' : 'Xác thực Email OTP (6 số)',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mã xác thực 6 số đã được gửi tới Email ${state.pendingOtpEmail}. Vui lòng kiểm tra hộp thư của bạn.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.pin_outlined),
              hintText: 'Nhập mã OTP 6 chữ số',
              counterText: '',
            ),
          ),
          if (isReset) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded),
                hintText: 'Nhập mật khẩu mới',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassConfirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_reset_rounded),
                hintText: 'Xác nhận mật khẩu mới',
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      if (isReset) {
                        final ok = await context.read<AuthCubit>().resetPassword(
                              otpCode: _otpCtrl.text,
                              newPassword: _newPassCtrl.text,
                              confirmPassword: _newPassConfirmCtrl.text,
                            );
                        if (ok && mounted) {
                          setState(() => _isLoginTab = true);
                        }
                      } else {
                        await context
                            .read<AuthCubit>()
                            .verifyRegisterOtp(_otpCtrl.text);
                      }
                    },
              child: Text(
                isReset
                    ? 'Xác nhận đổi mật khẩu'
                    : 'Xác nhận OTP & Vào Trang chủ',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.read<AuthCubit>().cancelOtpStep(),
              child: const Text('Quay lại'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, {required bool requiredField}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: text),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
        ],
      ),
    );
  }
}

