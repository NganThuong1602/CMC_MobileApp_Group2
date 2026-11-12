import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Màn hình Xác thực chuẩn Pixel-perfect theo Ảnh 1 (Đăng nhập) & Ảnh 2 (Đăng ký)
/// kèm bước nhập mã OTP 6 số gửi qua Email (Nodemailer NestJS)
/// và hiển thị thông báo Validate trực tiếp ngay dưới từng ô nhập liệu (`errorText`).
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

  // Login controllers & inline errors
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  String? _loginEmailError;
  String? _loginPassError;

  // Register controllers & inline errors
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  String? _regNameError;
  String? _regEmailError;
  String? _regPhoneError;
  String? _regPassError;
  String? _regConfirmError;

  // OTP & Reset Password controllers & inline errors
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _newPassConfirmCtrl = TextEditingController();
  String? _otpError;
  String? _newPassError;
  String? _newPassConfirmError;

  static final RegExp _emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

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

  bool _validateLoginFields() {
    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    String? emailErr;
    String? passErr;

    if (email.isEmpty) {
      emailErr = 'Vui lòng nhập địa chỉ Email';
    } else if (!_emailRegex.hasMatch(email)) {
      emailErr = 'Định dạng Email không hợp lệ (VD: user@barbersmart.vn)';
    }

    if (pass.isEmpty) {
      passErr = 'Vui lòng nhập mật khẩu';
    } else if (pass.length < 6) {
      passErr = 'Mật khẩu phải từ 6 ký tự trở lên';
    }

    setState(() {
      _loginEmailError = emailErr;
      _loginPassError = passErr;
    });
    return emailErr == null && passErr == null;
  }

  bool _validateRegisterFields() {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final pass = _regPassCtrl.text;
    final confirm = _regConfirmCtrl.text;

    String? nameErr;
    String? emailErr;
    String? phoneErr;
    String? passErr;
    String? confirmErr;

    if (name.isEmpty) {
      nameErr = 'Vui lòng nhập họ và tên của bạn';
    } else if (name.length < 2) {
      nameErr = 'Họ và tên phải có ít nhất 2 ký tự';
    }

    if (email.isEmpty) {
      emailErr = 'Vui lòng nhập địa chỉ Email xác thực';
    } else if (!_emailRegex.hasMatch(email)) {
      emailErr = 'Email không đúng định dạng (VD: tenban@gmail.com)';
    }

    phoneErr = AppFormatters.validateVietnamPhone(phone);

    if (pass.isEmpty) {
      passErr = 'Vui lòng nhập mật khẩu';
    } else if (pass.length < 6) {
      passErr = 'Mật khẩu phải có ít nhất 6 ký tự';
    }

    if (confirm.isEmpty) {
      confirmErr = 'Vui lòng nhập lại mật khẩu xác nhận';
    } else if (confirm != pass) {
      confirmErr = 'Mật khẩu xác nhận không khớp với mật khẩu đã nhập';
    }

    setState(() {
      _regNameError = nameErr;
      _regEmailError = emailErr;
      _regPhoneError = phoneErr;
      _regPassError = passErr;
      _regConfirmError = confirmErr;
    });

    return nameErr == null &&
        emailErr == null &&
        phoneErr == null &&
        passErr == null &&
        confirmErr == null;
  }

  bool _validateOtpFields({required bool isReset}) {
    final otp = _otpCtrl.text.trim();
    String? otpErr;
    String? newPassErr;
    String? confirmErr;

    if (otp.isEmpty) {
      otpErr = 'Vui lòng nhập mã OTP 6 chữ số';
    } else if (otp.length != 6 || int.tryParse(otp) == null) {
      otpErr = 'Mã OTP phải gồm đúng 6 chữ số';
    }

    if (isReset) {
      final newPass = _newPassCtrl.text;
      final confirm = _newPassConfirmCtrl.text;
      if (newPass.isEmpty) {
        newPassErr = 'Vui lòng nhập mật khẩu mới';
      } else if (newPass.length < 6) {
        newPassErr = 'Mật khẩu mới phải có ít nhất 6 ký tự';
      }
      if (confirm.isEmpty) {
        confirmErr = 'Vui lòng xác nhận mật khẩu mới';
      } else if (confirm != newPass) {
        confirmErr = 'Xác nhận mật khẩu mới không khớp';
      }
    }

    setState(() {
      _otpError = otpErr;
      _newPassError = newPassErr;
      _newPassConfirmError = confirmErr;
    });

    return otpErr == null && newPassErr == null && confirmErr == null;
  }

  void _showForgotPasswordDialog() {
    final tt = context.appTextStyles;
    final emailCtrl = TextEditingController(text: _loginEmailCtrl.text.trim());
    String? emailError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Quên mật khẩu?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập địa chỉ Email đã đăng ký để nhận mã xác thực OTP 6 số:',
                style: tt.bodyMuted,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (emailError != null) {
                    setModalState(() => emailError = null);
                  }
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  hintText: 'Nhập địa chỉ email',
                  errorText: emailError,
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
                if (email.isEmpty) {
                  setModalState(
                    () => emailError = 'Vui lòng nhập địa chỉ Email đã đăng ký',
                  );
                  return;
                }
                if (!_emailRegex.hasMatch(email)) {
                  setModalState(
                    () => emailError = 'Định dạng Email không hợp lệ',
                  );
                  return;
                }
                Navigator.pop(ctx);
                context.read<AuthCubit>().requestForgotPasswordOtp(email);
              },
              child: const Text('Gửi OTP'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go('/');
          return;
        }
        if (state.errorMessage != null) {
          final msg = state.errorMessage!;
          setState(() {
            if (state.pendingOtpEmail != null) {
              _otpError = msg;
            } else if (_isLoginTab) {
              _loginPassError = msg;
            } else if (msg.toLowerCase().contains('email')) {
              _regEmailError = msg;
            } else if (msg.toLowerCase().contains('điện thoại') ||
                msg.toLowerCase().contains('phone')) {
              _regPhoneError = msg;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: cs.error,
            ),
          );
        } else if (state.infoMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.infoMessage!),
              backgroundColor: cs.primary,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: cs.surfaceContainerLowest,
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
                      _buildLogoHeader(context),
                      const SizedBox(height: 24),
                      if (state.pendingOtpEmail != null)
                        _buildOtpVerificationCard(context, state)
                      else ...[
                        _buildSegmentedSwitcher(context),
                        const SizedBox(height: 20),
                        if (_isLoginTab)
                          _buildLoginForm(context, state)
                        else
                          _buildRegisterForm(context, state),
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

  Widget _buildLogoHeader(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.content_cut_rounded,
            color: cs.primary,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppConstants.appName,
          style: tt.brandLogo,
        ),
        const SizedBox(height: 6),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: tt.bodyMuted,
        ),
      ],
    );
  }

  Widget _buildSegmentedSwitcher(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
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
                  color: _isLoginTab ? cs.primary : AppTheme.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng nhập',
                  style: _isLoginTab ? tt.buttonLabel : tt.bodyStrong,
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
                  color: !_isLoginTab ? cs.primary : AppTheme.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng ký',
                  style: !_isLoginTab ? tt.buttonLabel : tt.bodyStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: appColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel(context, 'Email', requiredField: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_loginEmailError != null) {
                    setState(() => _loginEmailError = null);
                  }
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  hintText: 'Nhập email',
                  errorText: _loginEmailError,
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel(context, 'Mật khẩu', requiredField: false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginPassCtrl,
                obscureText: _obscureLoginPass,
                onChanged: (_) {
                  if (_loginPassError != null) {
                    setState(() => _loginPassError = null);
                  }
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  hintText: 'Nhập mật khẩu',
                  errorText: _loginPassError,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureLoginPass = !_obscureLoginPass),
                    icon: Icon(
                      _obscureLoginPass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.onSurfaceVariant,
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
                    foregroundColor: cs.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 28),
                  ),
                  child: Text(
                    'Quên mật khẩu?',
                    style: tt.bodySmallPrimary,
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
                          if (!_validateLoginFields()) return;
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

  Widget _buildRegisterForm(BuildContext context, AuthState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(context, 'Họ tên', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regNameCtrl,
          onChanged: (_) {
            if (_regNameError != null) {
              setState(() => _regNameError = null);
            }
          },
          decoration: InputDecoration(
            fillColor: cs.surface,
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            hintText: 'Nhập họ và tên',
            errorText: _regNameError,
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel(context, 'Email xác thực', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_regEmailError != null) {
              setState(() => _regEmailError = null);
            }
          },
          decoration: InputDecoration(
            fillColor: cs.surface,
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            hintText: 'Nhập địa chỉ email',
            errorText: _regEmailError,
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel(context, 'Số điện thoại', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regPhoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) {
            if (_regPhoneError != null) {
              setState(() => _regPhoneError = null);
            }
          },
          decoration: InputDecoration(
            fillColor: cs.surface,
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            hintText: 'Nhập số điện thoại',
            errorText: _regPhoneError,
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel(context, 'Mật khẩu', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regPassCtrl,
          obscureText: _obscureRegPass,
          onChanged: (_) {
            if (_regPassError != null) {
              setState(() => _regPassError = null);
            }
          },
          decoration: InputDecoration(
            fillColor: cs.surface,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            hintText: 'Nhập mật khẩu',
            errorText: _regPassError,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureRegPass = !_obscureRegPass),
              icon: Icon(
                _obscureRegPass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel(context, 'Nhập lại mật khẩu', requiredField: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _regConfirmCtrl,
          obscureText: _obscureRegConfirm,
          onChanged: (_) {
            if (_regConfirmError != null) {
              setState(() => _regConfirmError = null);
            }
          },
          decoration: InputDecoration(
            fillColor: cs.surface,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            hintText: 'Nhập lại mật khẩu',
            errorText: _regConfirmError,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureRegConfirm = !_obscureRegConfirm),
              icon: Icon(
                _obscureRegConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: tt.bodySmallMuted,
              children: [
                const TextSpan(text: 'Bằng việc bấm đăng ký, bạn đồng ý với '),
                TextSpan(
                  text: 'Điều khoản',
                  style: tt.underlineLinkPrimary,
                ),
                const TextSpan(text: ' và '),
                TextSpan(
                  text: 'Bảo mật',
                  style: tt.underlineLinkPrimary,
                ),
                const TextSpan(text: ' của Barbersmart.'),
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
                    if (!_validateRegisterFields()) return;
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

  Widget _buildOtpVerificationCard(BuildContext context, AuthState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final isReset = state.isForgotPasswordFlow;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: appColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReset ? 'Khôi phục mật khẩu (OTP)' : 'Xác thực Email OTP (6 số)',
            style: tt.dialogTitle,
          ),
          const SizedBox(height: 6),
          Text(
            'Mã xác thực 6 số đã được gửi tới Email ${state.pendingOtpEmail}. Vui lòng kiểm tra hộp thư của bạn.',
            style: tt.bodySmallMuted,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (_) {
              if (_otpError != null) {
                setState(() => _otpError = null);
              }
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.pin_outlined),
              hintText: 'Nhập mã OTP 6 chữ số',
              counterText: '',
              errorText: _otpError,
            ),
          ),
          if (isReset) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassCtrl,
              obscureText: true,
              onChanged: (_) {
                if (_newPassError != null) {
                  setState(() => _newPassError = null);
                }
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                hintText: 'Nhập mật khẩu mới',
                errorText: _newPassError,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassConfirmCtrl,
              obscureText: true,
              onChanged: (_) {
                if (_newPassConfirmError != null) {
                  setState(() => _newPassConfirmError = null);
                }
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                hintText: 'Xác nhận mật khẩu mới',
                errorText: _newPassConfirmError,
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
                      if (!_validateOtpFields(isReset: isReset)) return;
                      if (isReset) {
                        final ok =
                            await context.read<AuthCubit>().resetPassword(
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

  Widget _buildFieldLabel(
    BuildContext context,
    String text, {
    required bool requiredField,
  }) {
    final tt = context.appTextStyles;
    return RichText(
      text: TextSpan(
        style: tt.bodyStrong,
        children: [
          TextSpan(text: text),
          if (requiredField)
            TextSpan(
              text: ' *',
              style: tt.bodySmallDanger,
            ),
        ],
      ),
    );
  }
}
