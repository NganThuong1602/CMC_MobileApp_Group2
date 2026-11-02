import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../widgets/image_picker_widgets.dart';
import '../../widgets/sepay_qr_dialog.dart';

/// Màn hình Đăng ký Quán (100.000đ qua SePay VietQR động + Socket.IO):
/// - Mỗi Manager CHỈ sở hữu tối đa 1 quán.
/// - Hỗ trợ tải ảnh bìa từ Thiết bị (Cloudinary) hoặc nhập URL trực tiếp + lấy GPS thật của quán.
/// - Thanh toán xong SePay bắn Webhook -> nâng Role lên MANAGER ngay lập tức.
class RegisterShopPage extends StatefulWidget {
  const RegisterShopPage({super.key});

  @override
  State<RegisterShopPage> createState() => _RegisterShopPageState();
}

class _RegisterShopPageState extends State<RegisterShopPage> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _openCtrl = TextEditingController(text: '08:30');
  final _closeCtrl = TextEditingController(text: '20:30');
  String _coverUrl = '';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    setState(() => _submitting = true);
    final gps = await sl<LocationService>().requestAndGetCurrentLocation();
    final lat = gps?.latitude ?? AppConstants.defaultLat;
    final lng = gps?.longitude ?? AppConstants.defaultLng;

    final res = await sl<ShopRepository>().createRegisterShopPayment(
      userId: user.id,
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      phone: _phoneCtrl.text,
      description: _descCtrl.text,
      openTime: _openCtrl.text,
      closeTime: _closeCtrl.text,
      latitude: lat,
      longitude: lng,
      coverImageUrl: _coverUrl.trim().isNotEmpty ? _coverUrl.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: AppTheme.dangerRed),
      ),
      onSuccess: (tx) async {
        final paid = await SepayQrDialog.show(
          context,
          title: 'Thanh toán phí mở quán (SePay)',
          transaction: tx,
        );
        if (!mounted) return;
        if (paid) {
          await context.read<AuthCubit>().refreshCurrentUser();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.primaryGreen,
              content: Text(
                'Chúc mừng! Quán đã kích hoạt và tài khoản đã nâng lên Quản lý quán!',
              ),
            ),
          );
          context.go('/');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Đăng ký mở quán'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Phí kích hoạt cửa hàng: ${AppFormatters.formatVnd(AppConstants.shopRegistrationFeeVnd)}.\n'
              'Hệ thống tạo mã VietQR động qua SePay. Ngay khi chuyển khoản, tài khoản tự động nâng cấp lên Quản lý quán (tối đa 1 quán/tài khoản).',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên quán cắt tóc (Duy nhất) *',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addrCtrl,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ chi tiết (Duy nhất) *',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _openCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giờ mở cửa',
                    prefixIcon: Icon(Icons.wb_sunny_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _closeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giờ đóng cửa',
                    prefixIcon: Icon(Icons.nights_stay_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleImagePickerField(
            label: 'Ảnh bìa quán cắt tóc (Tải từ thiết bị / URL)',
            initialUrl: _coverUrl,
            isCircularPreview: false,
            onChanged: (url) => _coverUrl = url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Giới thiệu ngắn gọn về quán',
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.qr_code_rounded),
            label: Text(
              _submitting
                  ? 'Đang khởi tạo mã VietQR...'
                  : 'Tạo mã QR SePay 100.000đ & Kích hoạt',
            ),
          ),
        ],
      ),
    );
  }
}

