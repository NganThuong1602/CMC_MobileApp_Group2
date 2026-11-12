import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/finance_entities.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/image_picker_widgets.dart';
import '../../widgets/sepay_qr_dialog.dart';

class RegisterShopPage extends StatefulWidget {
  const RegisterShopPage({super.key});

  @override
  State<RegisterShopPage> createState() => _RegisterShopPageState();
}

class _RegisterShopPageState extends State<RegisterShopPage> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _openCtrl = TextEditingController(text: '08:30');
  final _closeCtrl = TextEditingController(text: '20:30');
  final _descCtrl = TextEditingController();
  String _coverUrl = '';
  bool _submitting = false;
  bool _loadingExisting = true;
  ShopEntity? _submittedShop;
  bool _showSubmittedDetails = true;
  RegisterShopCredit? _paidCredit;
  ShopPackagePlan _selectedPlan = ShopPackagePlan.coopMonthly;
  bool _creatingPackageQr = false;

  // Bản đồ chọn & tinh chỉnh vị trí quán
  final MapController _pickerMapController = MapController();
  bool _pickerMapReady = false;
  bool _geocodingAddress = false;
  String? _geocodedPlaceLabel;
  Timer? _addressDebounce;

  double _selectedLat = AppConstants.defaultLat;
  double _selectedLng = AppConstants.defaultLng;
  double _userLat = AppConstants.defaultLat;
  double _userLng = AppConstants.defaultLng;

  String? _nameError;
  String? _addrError;
  String? _phoneError;
  String? _openError;
  String? _closeError;
  String? _coverError;
  bool _hasUserGps = false;

  @override
  void initState() {
    super.initState();
    try {
      final discovery = sl<ShopDiscoveryCubit>().state;
      _userLat = discovery.userLat;
      _userLng = discovery.userLng;
      _selectedLat = discovery.userLat;
      _selectedLng = discovery.userLng;
      _hasUserGps = discovery.showUserLocationDot;
    } catch (_) {}
    _loadExistingShopAndLocation();
  }

  Future<void> _loadExistingShopAndLocation() async {
    final user = context.read<AuthCubit>().state.user;
    if (user != null) {
      final res = await sl<ShopRepository>().getShopByOwnerId(user.id);
      if (mounted && res.data != null) {
        setState(() {
          _submittedShop = res.data;
          _loadingExisting = false;
        });
        return;
      }

      final creditRes = await sl<ShopRepository>().getRegisterShopCredit();
      if (mounted && creditRes.data?.hasCredit == true) {
        setState(() {
          _paidCredit = creditRes.data;
          if (creditRes.data?.packagePlan != null) {
            _selectedPlan = creditRes.data!.packagePlan!;
          }
        });
      }
    }

    if (mounted) {
      setState(() => _loadingExisting = false);
    }

    // Lấy tọa độ GPS thực tế của thiết bị cho bản đồ chọn vị trí
    final loc = await sl<LocationService>().requestAndGetCurrentLocation();
    if (!mounted) return;
    if (loc == null || !loc.granted) {
      setState(() => _hasUserGps = false);
      return;
    }
    setState(() {
      _hasUserGps = true;
      _userLat = loc.latitude;
      _userLng = loc.longitude;
      if (_addrCtrl.text.trim().isEmpty) {
        _selectedLat = loc.latitude;
        _selectedLng = loc.longitude;
      }
    });
    if (_addrCtrl.text.trim().isEmpty) {
      _movePickerMap(loc.latitude, loc.longitude);
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _movePickerMap(double lat, double lng, {double zoom = 16.0}) {
    if (!_pickerMapReady || !mounted) return;
    _pickerMapController.move(LatLng(lat, lng), zoom);
  }

  void _onAddressTextChanged(String val) {
    if (_addrError != null) {
      setState(() => _addrError = null);
    }
    _addressDebounce?.cancel();
    if (val.trim().length < 5) return;
    _addressDebounce = Timer(const Duration(milliseconds: 650), () {
      _locateAddressOnMap(showFeedback: false);
    });
  }

  Future<void> _locateAddressOnMap({bool showFeedback = true}) async {
    final raw = _addrCtrl.text.trim();
    if (raw.isEmpty) {
      if (showFeedback && mounted) {
        setState(() => _addrError = 'Vui lòng nhập địa chỉ để tìm trên bản đồ');
      }
      return;
    }

    setState(() => _geocodingAddress = true);
    final found = await sl<LocationService>().geocodeAddress(raw);
    if (!mounted) return;
    setState(() {
      _geocodingAddress = false;
      if (found != null) {
        _selectedLat = found.latitude;
        _selectedLng = found.longitude;
        _geocodedPlaceLabel = found.displayName;
      }
    });

    if (found != null) {
      _movePickerMap(found.latitude, found.longitude, zoom: 16.2);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colorScheme.primary,
            content: const Text('Đã định vị địa chỉ trên bản đồ'),
          ),
        );
      }
    } else if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy tự động, vui lòng chọn vị trí trên bản đồ'),
        ),
      );
    }
  }

  Future<void> _pinAtMyRealGps() async {
    final loc = await sl<LocationService>().requestAndGetCurrentLocation();
    if (!mounted) return;
    if (loc != null && loc.granted) {
      setState(() {
        _hasUserGps = true;
        _userLat = loc.latitude;
        _userLng = loc.longitude;
        _selectedLat = loc.latitude;
        _selectedLng = loc.longitude;
        _geocodedPlaceLabel = 'Tọa độ GPS hiện tại của bạn';
      });
      _movePickerMap(loc.latitude, loc.longitude, zoom: 16.2);
    } else {
      setState(() {
        _hasUserGps = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng bật định vị để lấy vị trí GPS của bạn.'),
        ),
      );
    }
  }

  bool _validateForm() {
    final name = _nameCtrl.text.trim();
    final addr = _addrCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final open = _openCtrl.text.trim();
    final close = _closeCtrl.text.trim();
    final hhMmRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

    final nameErr = name.isEmpty
        ? 'Vui lòng nhập tên quán cắt tóc'
        : (name.length < 2 ? 'Tên quán phải từ 2 ký tự trở lên' : null);
    final addrErr = addr.isEmpty
        ? 'Vui lòng nhập địa chỉ chi tiết của quán'
        : (addr.length < 5 ? 'Vui lòng nhập địa chỉ cụ thể hơn' : null);
    final phoneErr = AppFormatters.validateVietnamPhone(phone);
    final openErr = open.isEmpty
        ? 'Vui lòng nhập giờ mở cửa'
        : (!hhMmRegex.hasMatch(open) ? 'Định dạng chuẩn HH:mm (VD: 08:30)' : null);
    final closeErr = close.isEmpty
        ? 'Vui lòng nhập giờ đóng cửa'
        : (!hhMmRegex.hasMatch(close) ? 'Định dạng chuẩn HH:mm (VD: 20:30)' : null);

    setState(() {
      _nameError = nameErr;
      _addrError = addrErr;
      _phoneError = phoneErr;
      _openError = openErr;
      _closeError = closeErr;
      _coverError = null;
    });

    return nameErr == null &&
        addrErr == null &&
        phoneErr == null &&
        openErr == null &&
        closeErr == null;
  }

  Future<void> _paySelectedPackage() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    setState(() => _creatingPackageQr = true);
    final repo = sl<ShopRepository>();
    final txRes = await repo.createPackageRegistrationPayment(
      userId: user.id,
      packagePlan: _selectedPlan,
    );
    if (!mounted) return;
    setState(() => _creatingPackageQr = false);

    txRes.fold(
      onFailure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colorScheme.error,
            content: Text(f.message),
          ),
        );
      },
      onSuccess: (tx) async {
        final paid = await SepayQrDialog.show(
          context,
          transaction: tx,
          title: 'Thanh toán ${_selectedPlan.label} (SePay)',
        );
        if (paid && mounted) {
          final creditRes = await repo.getRegisterShopCredit();
          if (!mounted) return;
          setState(() {
            _paidCredit = (creditRes.data?.hasCredit == true)
                ? creditRes.data
                : RegisterShopCredit(
                    hasCredit: true,
                    paymentCode: tx.paymentCode,
                    packagePlan: _selectedPlan,
                    amount: tx.amount,
                    paidAt: DateTime.now(),
                  );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: context.colorScheme.primary,
              content: Text(
                'Đã thanh toán ${_selectedPlan.label} thành công! Vui lòng điền thông tin quán để gửi Admin duyệt.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _submitShopFormAfterPayment() async {
    if (!_validateForm()) return;

    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    setState(() => _submitting = true);

    final repo = sl<ShopRepository>();
    final submitRes = await repo.submitShopRegistrationAfterPayment(
      userId: user.id,
      paymentCode: _paidCredit?.paymentCode ?? '',
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      phone: _phoneCtrl.text,
      description: _descCtrl.text,
      openTime: _openCtrl.text,
      closeTime: _closeCtrl.text,
      latitude: _selectedLat,
      longitude: _selectedLng,
      coverImageUrl: _coverUrl,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    submitRes.fold(
      onFailure: (f) {
        final msg = f.message.toLowerCase();
        setState(() {
          if (msg.contains('tên quán')) {
            _nameError = f.message;
          } else if (msg.contains('địa chỉ')) {
            _addrError = f.message;
          } else if (msg.contains('điện thoại') || msg.contains('sđt')) {
            _phoneError = f.message;
          } else {
            _nameError = f.message;
          }
        });
      },
      onSuccess: (createdShop) async {
        await context.read<AuthCubit>().refreshCurrentUser();
        if (!mounted) return;
        try {
          sl<ShopDiscoveryCubit>().loadAll(userId: user.id);
        } catch (_) {}
        setState(() {
          _submittedShop = createdShop;
          _showSubmittedDetails = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colorScheme.primary,
            content: const Text(
              'Đã gửi hồ sơ đăng ký quán! Trạng thái hiện tại: "Chờ duyệt" để Admin xem xét.',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

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
        title: Text(
          _submittedShop != null
              ? 'Trạng thái đăng ký quán'
              : _paidCredit?.hasCredit == true
                  ? 'Điền hồ sơ đăng ký quán'
                  : 'Chọn gói đăng ký quán',
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : _submittedShop != null
              ? _buildSubmittedShopStatusView(context, _submittedShop!)
              : _paidCredit?.hasCredit == true
                  ? _buildRegistrationFormView(context, cs, tt)
                  : _buildPackageSelectionView(context, cs, tt),
    );
  }

  /// Màn hình hiển thị Trạng thái Hồ sơ Quán ("Đang chờ duyệt" / "Đã duyệt")
  /// và khi bấm vào sẽ hiện toàn bộ thông tin quán đã điền.
  Widget _buildSubmittedShopStatusView(BuildContext context, ShopEntity shop) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final isApproved = shop.isActive;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _showSubmittedDetails = !_showSubmittedDetails;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isApproved
                  ? cs.primaryContainer
                  : appColors.warningContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isApproved
                    ? cs.primary.withValues(alpha: 0.4)
                    : appColors.warning.withValues(alpha: 0.5),
              ),
              boxShadow: appColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isApproved ? cs.primary : appColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isApproved
                            ? Icons.verified_rounded
                            : Icons.hourglass_top_rounded,
                        color: cs.onPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isApproved
                                  ? 'TRẠNG THÁI: ĐÃ DUYỆT'
                                  : 'TRẠNG THÁI: ĐANG CHỜ DUYỆT',
                              style: tt.badgePrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            shop.name,
                            style: tt.sectionTitle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isApproved
                      ? 'Hồ sơ đăng ký quán của bạn đã được Admin phê duyệt. Quán đang hoạt động chính thức trên hệ thống BarberSmart.'
                      : 'Bạn đã thanh toán phí đăng ký mở quán thành công. Hồ sơ quán đang chờ Admin hệ thống kiểm tra và phê duyệt.',
                  style: tt.bodyRegular,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _showSubmittedDetails
                              ? 'Ẩn thông tin chi tiết'
                              : 'Xem thông tin chi tiết',
                          style: tt.bodyStrong,
                        ),
                      ),
                      Icon(
                        _showSubmittedDetails
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSubmittedDetails) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: appColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin quán đã đăng ký',
                  style: tt.sectionTitle,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    shop.coverImageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: cs.surfaceContainerLow,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.storefront_rounded,
                        color: cs.primary,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (shop.subscriptionPlan != null) ...[
                  _buildSubmittedInfoRow(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    label: 'Gói đã đăng ký',
                    value:
                        '${shop.subscriptionPlan!.label} (${shop.subscriptionPlan!.isCooperation ? 'Hỗ trợ Nổi bật & Mã giảm giá' : 'Gói tiêu chuẩn'})',
                  ),
                  const Divider(height: 20),
                ],
                if (shop.paymentAmount > 0 || shop.paymentCode.isNotEmpty) ...[
                  _buildSubmittedInfoRow(
                    context,
                    icon: Icons.payments_outlined,
                    label: 'Thanh toán SePay',
                    value: [
                      if (shop.paymentAmount > 0)
                        AppFormatters.formatVnd(shop.paymentAmount),
                      if (shop.paymentCode.isNotEmpty)
                        'Mã GD: ${shop.paymentCode}',
                    ].join(' • '),
                  ),
                  const Divider(height: 20),
                ],
                _buildSubmittedInfoRow(
                  context,
                  icon: Icons.storefront_outlined,
                  label: 'Tên quán cắt tóc',
                  value: shop.name,
                ),
                const Divider(height: 20),
                _buildSubmittedInfoRow(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ chi tiết',
                  value: shop.address,
                ),
                const Divider(height: 20),
                _buildSubmittedInfoRow(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Số điện thoại liên hệ',
                  value: shop.phone,
                ),
                const Divider(height: 20),
                _buildSubmittedInfoRow(
                  context,
                  icon: Icons.access_time_rounded,
                  label: 'Giờ hoạt động',
                  value: '${shop.openTime} - ${shop.closeTime}',
                ),
                const Divider(height: 20),
                _buildSubmittedInfoRow(
                  context,
                  icon: Icons.notes_rounded,
                  label: 'Giới thiệu quán',
                  value: shop.description,
                ),
                const SizedBox(height: 14),
                Text(
                  'Vị trí quán trên bản đồ (${shop.latitude.toStringAsFixed(5)}, ${shop.longitude.toStringAsFixed(5)})',
                  style: tt.cardTitle,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 185,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(shop.latitude, shop.longitude),
                        initialZoom: 15.8,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: AppConstants.osmTileUrl,
                          userAgentPackageName:
                              AppConstants.osmUserAgentPackage,
                        ),
                        MarkerLayer(
                          markers: [
                            _buildShopPinMarker(
                              context,
                              point: LatLng(shop.latitude, shop.longitude),
                              label: shop.name,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmittedInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.captionMuted),
              const SizedBox(height: 3),
              Text(value, style: tt.bodyStrong),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageSelectionView(
    BuildContext context,
    ColorScheme cs,
    AppTextStyles tt,
  ) {
    final appColors = context.appColors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bước 1/2: Chọn gói đăng ký & Thanh toán SePay',
                style: tt.sectionTitlePrimary,
              ),
              const SizedBox(height: 4),
              Text(
                'Thanh toán gói thành công sẽ tự động mở khóa bước điền thông tin mở quán để gửi Admin duyệt.',
                style: tt.bodySmallPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...ShopPackagePlan.values.map((plan) {
          final selected = _selectedPlan == plan;
          return GestureDetector(
            onTap: () => setState(() => _selectedPlan = plan),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? cs.primaryContainer : cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: selected ? 2 : 1,
                ),
                boxShadow: appColors.cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(plan.label, style: tt.cardTitle),
                            ),
                            if (plan.isCooperation)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Nổi bật & Ưu đãi',
                                  style: tt.badgeOnPrimary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppFormatters.formatVnd(plan.price)} • Hiệu lực ${plan.durationDays} ngày',
                          style: tt.pricePrimary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plan.benefitDescription,
                          style: tt.bodySmallMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ưu đãi của gói đang chọn', style: tt.sectionTitle),
              const SizedBox(height: 6),
              Text(_selectedPlan.label, style: tt.bodyStrong),
              const SizedBox(height: 4),
              Text(_selectedPlan.benefitDescription, style: tt.bodySmallMuted),
              if (_selectedPlan.isCooperation) ...[
                const SizedBox(height: 6),
                Text(
                  '• Quán được ưu tiên đẩy lên đầu Trang chủ ("Nổi bật") và xuất hiện trong bộ lọc Nổi bật.\n'
                  '• Tự động áp dụng các chương trình Mã giảm giá do Admin tạo.',
                  style: tt.bodySmallPrimary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _creatingPackageQr ? null : _paySelectedPackage,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(
              _creatingPackageQr
                  ? 'Đang tạo mã VietQR...'
                  : 'Thanh toán ${AppFormatters.formatVnd(_selectedPlan.price)} qua SePay',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationFormView(
    BuildContext context,
    ColorScheme cs,
    AppTextStyles tt,
  ) {
    final appColors = context.appColors;
    final paidPlan = _paidCredit?.packagePlan ?? _selectedPlan;
    final paidAmount = _paidCredit?.amount ?? paidPlan.price;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Đã thanh toán ${paidPlan.label} (${AppFormatters.formatVnd(paidAmount)}).\n'
            'Bước 2/2: Vui lòng hoàn tất thông tin cửa hàng dưới đây và bấm "Xác nhận" để gửi Admin phê duyệt mở quán.',
            style: tt.bodySmallPrimary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtrl,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            labelText: 'Tên quán cắt tóc (Duy nhất) *',
            prefixIcon: const Icon(Icons.storefront),
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addrCtrl,
          onChanged: _onAddressTextChanged,
          onSubmitted: (_) => _locateAddressOnMap(showFeedback: true),
          decoration: InputDecoration(
            labelText: 'Địa chỉ chi tiết (Duy nhất) *',
            hintText: 'VD: 19b, ngõ 31, phố Lụa, Vạn Phúc, Hà Đông',
            prefixIcon: const Icon(Icons.location_on_outlined),
            errorText: _addrError,
            suffixIcon: _geocodingAddress
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Tìm vị trí địa chỉ này trên bản đồ',
                    onPressed: () => _locateAddressOnMap(showFeedback: true),
                    icon: Icon(Icons.travel_explore_rounded, color: cs.primary),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        // Khung Bản đồ tương tác chọn & chỉnh chính xác vị trí quán
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
            boxShadow: appColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.map_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vị trí quán trên bản đồ',
                      style: tt.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _geocodingAddress
                        ? null
                        : () => _locateAddressOnMap(showFeedback: true),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Định vị theo địa chỉ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pinAtMyRealGps,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Vị trí GPS của tôi'),
                  ),
                ],
              ),
              if (_geocodedPlaceLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Đã ghim: $_geocodedPlaceLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmallPrimary,
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 215,
                  child: FlutterMap(
                    mapController: _pickerMapController,
                    options: MapOptions(
                      initialCenter: LatLng(_selectedLat, _selectedLng),
                      initialZoom: 15.8,
                      onMapReady: () {
                        _pickerMapReady = true;
                        _movePickerMap(_selectedLat, _selectedLng, zoom: 15.8);
                      },
                      onTap: (_, latLng) {
                        setState(() {
                          _selectedLat = latLng.latitude;
                          _selectedLng = latLng.longitude;
                          _geocodedPlaceLabel =
                              'Đã ghim thủ công (${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})';
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: AppConstants.osmTileUrl,
                        userAgentPackageName: AppConstants.osmUserAgentPackage,
                      ),
                      MarkerLayer(
                        markers: [
                          _buildShopPinMarker(
                            context,
                            point: LatLng(_selectedLat, _selectedLng),
                            label: _nameCtrl.text.trim().isNotEmpty
                                ? _nameCtrl.text.trim()
                                : 'Vị trí quán',
                          ),
                          if (_hasUserGps)
                            _buildUserPinMarker(
                              context,
                              point: LatLng(_userLat, _userLng),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tọa độ quán: ${_selectedLat.toStringAsFixed(5)}, ${_selectedLng.toStringAsFixed(5)}',
                style: tt.captionMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          decoration: InputDecoration(
            labelText: 'Số điện thoại liên hệ *',
            prefixIcon: const Icon(Icons.phone_outlined),
            errorText: _phoneError,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _openCtrl,
                onChanged: (_) {
                  if (_openError != null) setState(() => _openError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Giờ mở cửa *',
                  prefixIcon: const Icon(Icons.wb_sunny_outlined),
                  errorText: _openError,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _closeCtrl,
                onChanged: (_) {
                  if (_closeError != null) setState(() => _closeError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Giờ đóng cửa *',
                  prefixIcon: const Icon(Icons.nights_stay_outlined),
                  errorText: _closeError,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleImagePickerField(
          label: 'Ảnh bìa quán cắt tóc (Tải từ thiết bị / URL)',
          initialUrl: _coverUrl,
          onChanged: (url) => setState(() {
            _coverUrl = url;
            _coverError = null;
          }),
        ),
        if (_coverError != null) ...[
          const SizedBox(height: 4),
          Text(_coverError!, style: tt.captionStrong),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Giới thiệu ngắn gọn về quán',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submitShopFormAfterPayment,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _submitting
                  ? 'Đang gửi hồ sơ quán...'
                  : 'Xác nhận & Gửi duyệt mở quán',
            ),
          ),
        ),
      ],
    );
  }

  Marker _buildUserPinMarker(BuildContext context, {required LatLng point}) {
    final cs = context.colorScheme;
    final appColors = context.appColors;

    // Chấm xanh dương kiểu Google Maps.
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appColors.info.withValues(alpha: 0.18),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: appColors.info,
            shape: BoxShape.circle,
            border: Border.all(color: cs.surface, width: 3),
            boxShadow: appColors.cardShadow,
          ),
        ),
      ),
    );
  }

  Marker _buildShopPinMarker(
    BuildContext context, {
    required LatLng point,
    required String label,
  }) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Marker(
      point: point,
      width: 145,
      height: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 2.5),
              boxShadow: appColors.cardShadow,
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: cs.onPrimary,
              size: 19,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: appColors.cardShadow,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.badgePrimary,
            ),
          ),
        ],
      ),
    );
  }
}
