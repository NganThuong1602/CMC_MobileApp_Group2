import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/finance_entities.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/barber_repository.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../../widgets/image_picker_widgets.dart';
import '../../widgets/sepay_qr_dialog.dart';

/// Màn hình Quản lý quán (Role MANAGER):
/// - Ảnh cover bo góc có gradient đáy, hiển thị Tên quán + Giờ mở cửa + SĐT đè lên ảnh.
/// - 5 Card menu bo góc:
///   1. `Quản lý thông tin` (Sửa thông tin quán, hình ảnh, Mua gói Nổi bật SePay 20k/50k/90k)
///   2. `Quản lý dịch vụ` (Nằm ngay dưới Quản lý thông tin: Danh sách dịch vụ + Thêm, Sửa, Xoá dịch vụ)
///   3. `Quản lý barber` (Tìm Email/SĐT mời làm Barber gửi thông báo thật, chỉnh lương cứng, Xoá barber)
///   4. `Tư vấn khách hàng` (Chat trực tiếp giữa Chủ quán và Khách hàng, nhận thông báo thật)
///   5. `Doanh thu và lương` (Chỉ cộng doanh thu & 10% hoa hồng từ lịch COMPLETED)
class MyShopPage extends StatefulWidget {
  final bool openCustomerConsult;
  final String? initialChatRoomId;
  final String? initialCustomerHint;
  final String? navigationToken;

  const MyShopPage({
    super.key,
    this.openCustomerConsult = false,
    this.initialChatRoomId,
    this.initialCustomerHint,
    this.navigationToken,
  });

  @override
  State<MyShopPage> createState() => _MyShopPageState();
}

class _MyShopPageState extends State<MyShopPage> {
  ShopEntity? _shop;
  bool _loading = true;
  String? _lastHandledConsultToken;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void didUpdateWidget(covariant MyShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCustomerConsult &&
        _shop != null &&
        widget.navigationToken != _lastHandledConsultToken) {
      _lastHandledConsultToken = widget.navigationToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shop != null) {
          _openCustomerConsultScreen(
            _shop!,
            initialRoomId: widget.initialChatRoomId,
            initialCustomerHint: widget.initialCustomerHint,
          );
        }
      });
    }
  }

  Future<void> _loadShop() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<ShopRepository>().getShopByOwnerId(user.id);
    if (mounted) {
      setState(() {
        _shop = res.data;
        _loading = false;
      });
      if (widget.openCustomerConsult &&
          _shop != null &&
          widget.navigationToken != _lastHandledConsultToken) {
        _lastHandledConsultToken = widget.navigationToken;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _shop != null) {
            _openCustomerConsultScreen(
              _shop!,
              initialRoomId: widget.initialChatRoomId,
              initialCustomerHint: widget.initialCustomerHint,
            );
          }
        });
      }
    }
  }

  void _openManageInfoSheet(ShopEntity shop) {
    final nameCtrl = TextEditingController(text: shop.name);
    final addrCtrl = TextEditingController(text: shop.address);
    final phoneCtrl = TextEditingController(text: shop.phone);
    final openCtrl = TextEditingController(text: shop.openTime);
    final closeCtrl = TextEditingController(text: shop.closeTime);
    final descCtrl = TextEditingController(text: shop.description);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _ManageShopInfoScreen(
          shop: shop,
          nameCtrl: nameCtrl,
          addrCtrl: addrCtrl,
          phoneCtrl: phoneCtrl,
          openCtrl: openCtrl,
          closeCtrl: closeCtrl,
          descCtrl: descCtrl,
          onUpdated: () {
            _loadShop();
            context.read<ShopDiscoveryCubit>().loadAll();
          },
        ),
      ),
    );
  }

  void _openManageServicesScreen(ShopEntity shop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManageShopServicesScreen(
          shop: shop,
          onUpdated: () {
            _loadShop();
            context.read<ShopDiscoveryCubit>().loadAll();
          },
        ),
      ),
    );
  }

  void _openManageBarbersScreen(ShopEntity shop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManageBarbersScreen(shop: shop),
      ),
    );
  }

  void _openCustomerConsultScreen(
    ShopEntity shop, {
    String? initialRoomId,
    String? initialCustomerHint,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManagerChatListScreen(
          shop: shop,
          initialRoomId: initialRoomId,
          initialCustomerHint: initialCustomerHint,
        ),
      ),
    );
  }

  void _openRevenueAndPayrollScreen(ShopEntity shop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ShopRevenuePayrollScreen(shop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final user = context.watch<AuthCubit>().state.user;

    return BlocBuilder<ShopDiscoveryCubit, ShopDiscoveryState>(
      builder: (context, discoveryState) {
        return Column(
          children: [
            BarberSmartHeader(
              unreadCount: discoveryState.unreadNotificationCount,
              onNotificationTap: () async {
                await context.push('/notifications');
                if (context.mounted) {
                  context
                      .read<ShopDiscoveryCubit>()
                      .loadAll(userId: user?.id);
                }
              },
              onProfileSocialTap: () => context.push('/profile-social'),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _shop == null
                      ? Center(
                          child: Text(
                            'Bạn chưa sở hữu cửa hàng nào.',
                            style: tt.bodyMuted,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                              height: 196,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: appColors.cardShadow,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _shop!.coverImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: cs.inverseSurface,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          appColors.bannerOverlayTop,
                                          appColors.bannerOverlayBottom,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _shop!.name,
                                          style: tt.cardTitleOnInverse,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 15,
                                                  color: cs.secondary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '${_shop!.openTime} - ${_shop!.closeTime}',
                                                  style: tt.bodySmallOnInverse,
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 15,
                                                  color: cs.secondary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  _shop!.phone,
                                                  style: tt.bodySmallOnInverse,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildManagerMenuCard(
                              context: context,
                              icon: Icons.storefront_outlined,
                              title: 'Quản lý thông tin',
                              onTap: () => _openManageInfoSheet(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
                              context: context,
                              icon: Icons.content_cut_rounded,
                              title: 'Quản lý dịch vụ',
                              onTap: () => _openManageServicesScreen(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
                              context: context,
                              icon: Icons.badge_outlined,
                              title: 'Quản lý barber',
                              onTap: () => _openManageBarbersScreen(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
                              context: context,
                              icon: Icons.support_agent_rounded,
                              title: 'Tư vấn khách hàng',
                              onTap: () => _openCustomerConsultScreen(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
                              context: context,
                              icon: Icons.payments_outlined,
                              title: 'Doanh thu và lương',
                              onTap: () =>
                                  _openRevenueAndPayrollScreen(_shop!),
                            ),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManagerMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: appColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: tt.cardTitle,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageShopInfoScreen extends StatefulWidget {
  final ShopEntity shop;
  final TextEditingController nameCtrl;
  final TextEditingController addrCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController openCtrl;
  final TextEditingController closeCtrl;
  final TextEditingController descCtrl;
  final VoidCallback onUpdated;

  const _ManageShopInfoScreen({
    required this.shop,
    required this.nameCtrl,
    required this.addrCtrl,
    required this.phoneCtrl,
    required this.openCtrl,
    required this.closeCtrl,
    required this.descCtrl,
    required this.onUpdated,
  });

  @override
  State<_ManageShopInfoScreen> createState() => _ManageShopInfoScreenState();
}

class _ManageShopInfoScreenState extends State<_ManageShopInfoScreen> {
  late String _coverImageUrl;
  late List<String> _galleryUrls;

  String? _nameError;
  String? _addrError;
  String? _phoneError;
  String? _openError;
  String? _closeError;

  @override
  void initState() {
    super.initState();
    _coverImageUrl = widget.shop.coverImageUrl;
    _galleryUrls = List<String>.from(widget.shop.galleryUrls);
  }

  bool _validateShopInfo() {
    final name = widget.nameCtrl.text.trim();
    final addr = widget.addrCtrl.text.trim();
    final phone = widget.phoneCtrl.text.trim();
    final open = widget.openCtrl.text.trim();
    final close = widget.closeCtrl.text.trim();
    final timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

    setState(() {
      _nameError = name.isEmpty ? 'Tên quán không được để trống' : null;
      _addrError = addr.isEmpty ? 'Địa chỉ quán không được để trống' : null;
      _phoneError = AppFormatters.validateVietnamPhone(phone);
      _openError = !timeRegex.hasMatch(open)
          ? 'Giờ mở cửa không hợp lệ (HH:mm)'
          : null;
      _closeError = !timeRegex.hasMatch(close)
          ? 'Giờ đóng cửa không hợp lệ (HH:mm)'
          : null;
    });

    return _nameError == null &&
        _addrError == null &&
        _phoneError == null &&
        _openError == null &&
        _closeError == null;
  }

  Future<void> _buyHighlight(HighlightPackageType pkg) async {
    final cs = context.colorScheme;
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<ShopRepository>().createHighlightPayment(
      userId: user.id,
      shopId: widget.shop.id,
      packageType: pkg,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: cs.error),
      ),
      onSuccess: (tx) async {
        final paid = await SepayQrDialog.show(
          context,
          title: 'Mua ${pkg.label} Nổi bật (SePay)',
          transaction: tx,
        );
        if (paid && mounted) {
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.primary,
              content: Text('Đã kích hoạt ${pkg.label} thành công!'),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thông tin & Nổi bật')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mua gói Nổi bật tự động qua SePay',
            style: tt.sectionTitle,
          ),
          const SizedBox(height: 8),
          Row(
            children: HighlightPackageType.values.map((pkg) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => _buyHighlight(pkg),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          pkg.label,
                          style: tt.bodySmallPrimary,
                        ),
                        Text(
                          AppFormatters.formatVnd(pkg.priceVnd),
                          style: tt.captionMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Thông tin cửa hàng',
            style: tt.sectionTitle,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.nameCtrl,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(
              labelText: 'Tên quán *',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.addrCtrl,
            onChanged: (_) {
              if (_addrError != null) setState(() => _addrError = null);
            },
            decoration: InputDecoration(
              labelText: 'Địa chỉ *',
              errorText: _addrError,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.openCtrl,
                  onChanged: (_) {
                    if (_openError != null) setState(() => _openError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Giờ mở cửa *',
                    errorText: _openError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.closeCtrl,
                  onChanged: (_) {
                    if (_closeError != null) setState(() => _closeError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Giờ đóng cửa *',
                    errorText: _closeError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.phoneCtrl,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            decoration: InputDecoration(
              labelText: 'Số điện thoại *',
              errorText: _phoneError,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Giới thiệu'),
          ),
          const SizedBox(height: 12),
          SingleImagePickerField(
            label: 'Ảnh bìa cửa hàng (Tải từ Thiết bị / URL)',
            initialUrl: _coverImageUrl,
            isCircularPreview: false,
            onChanged: (url) => _coverImageUrl = url,
          ),
          const SizedBox(height: 12),
          MultiImagePickerField(
            label: 'Bộ sưu tập ảnh không gian quán',
            initialUrls: _galleryUrls,
            maxImages: 5,
            onChanged: (urls) => setState(() => _galleryUrls = urls),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () async {
              if (!_validateShopInfo()) return;
              await sl<ShopRepository>().updateShopInfo(
                shopId: widget.shop.id,
                name: widget.nameCtrl.text.trim(),
                address: widget.addrCtrl.text.trim(),
                phone: widget.phoneCtrl.text.trim(),
                description: widget.descCtrl.text.trim(),
                openTime: widget.openCtrl.text.trim(),
                closeTime: widget.closeCtrl.text.trim(),
                coverImageUrl: _coverImageUrl.trim().isNotEmpty
                    ? _coverImageUrl.trim()
                    : widget.shop.coverImageUrl,
                galleryUrls: _galleryUrls,
              );
              widget.onUpdated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: cs.primary,
                    content: const Text('Đã lưu thông tin & hình ảnh quán!'),
                  ),
                );
              }
            },
            child: const Text('Lưu cập nhật thông tin'),
          ),
        ],
      ),
    );
  }
}

/// Màn hình Quản lý dịch vụ riêng biệt (nằm ngay dưới Quản lý thông tin):
/// Cho phép Chủ quán Thêm dịch vụ mới, Chỉnh sửa dịch vụ hoặc Xoá dịch vụ bất kỳ.
class _ManageShopServicesScreen extends StatefulWidget {
  final ShopEntity shop;
  final VoidCallback onUpdated;

  const _ManageShopServicesScreen({
    required this.shop,
    required this.onUpdated,
  });

  @override
  State<_ManageShopServicesScreen> createState() =>
      _ManageShopServicesScreenState();
}

class _ManageShopServicesScreenState extends State<_ManageShopServicesScreen> {
  List<ServiceEntity> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final res = await sl<ShopRepository>().getShopServices(widget.shop.id);
    if (mounted) {
      setState(() {
        _services = res.data ?? [];
        _loading = false;
      });
    }
  }

  void _showUpsertServiceDialog({ServiceEntity? existing}) {
    final cs = context.colorScheme;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: (existing?.price ?? 100000).toString(),
    );
    final durCtrl = TextEditingController(
      text: (existing?.durationMinutes ?? 30).toString(),
    );
    String? nameError;
    String? priceError;
    String? durError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm dịch vụ mới' : 'Chỉnh sửa dịch vụ',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                onChanged: (_) {
                  if (nameError != null) setModalState(() => nameError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Tên dịch vụ *',
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (priceError != null) {
                    setModalState(() => priceError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Giá (VNĐ) *',
                  errorText: priceError,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (durError != null) setModalState(() => durError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Thời lượng (phút) *',
                  errorText: durError,
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
              onPressed: () async {
                final cleanName = nameCtrl.text.trim();
                final parsedPrice = int.tryParse(priceCtrl.text.trim());
                final parsedDur = int.tryParse(durCtrl.text.trim());

                setModalState(() {
                  nameError = cleanName.isEmpty
                      ? 'Vui lòng nhập tên dịch vụ'
                      : null;
                  priceError = (parsedPrice == null || parsedPrice <= 0)
                      ? 'Giá dịch vụ phải là số nguyên lớn hơn 0'
                      : null;
                  durError = (parsedDur == null || parsedDur <= 0)
                      ? 'Thời lượng phải lớn hơn 0 phút'
                      : null;
                });

                if (nameError != null ||
                    priceError != null ||
                    durError != null) {
                  return;
                }

                final res = await sl<ShopRepository>().upsertService(
                  shopId: widget.shop.id,
                  serviceId: existing?.id,
                  name: cleanName,
                  price: parsedPrice!,
                  durationMinutes: parsedDur!,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                res.fold(
                  onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: cs.error,
                      content: Text(f.message),
                    ),
                  ),
                  onSuccess: (_) {
                    widget.onUpdated();
                    _loadServices();
                  },
                );
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý dịch vụ'),
        actions: [
          TextButton.icon(
            onPressed: () => _showUpsertServiceDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm dịch vụ'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Danh sách dịch vụ (${_services.length})',
                        style: tt.sectionTitle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showUpsertServiceDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm dịch vụ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Chưa có dịch vụ nào. Bấm "+ Thêm dịch vụ" để bắt đầu.',
                        style: tt.bodyMuted,
                      ),
                    ),
                  )
                else
                  ..._services.map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: appColors.cardShadow,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.name,
                          style: tt.bodyStrong,
                        ),
                        subtitle: Text(
                          '${s.durationMinutes} phút • ${AppFormatters.formatVnd(s.price)}',
                          style: tt.bodySmallMuted,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Chỉnh sửa dịch vụ',
                              icon: Icon(
                                Icons.edit_outlined,
                                color: cs.primary,
                              ),
                              onPressed: () =>
                                  _showUpsertServiceDialog(existing: s),
                            ),
                            IconButton(
                              tooltip: 'Xoá dịch vụ',
                              icon: Icon(
                                Icons.delete_outline,
                                color: cs.error,
                              ),
                              onPressed: () async {
                                await sl<ShopRepository>().deleteService(
                                  shopId: widget.shop.id,
                                  serviceId: s.id,
                                );
                                widget.onUpdated();
                                _loadServices();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ManageBarbersScreen extends StatefulWidget {
  final ShopEntity shop;
  const _ManageBarbersScreen({required this.shop});

  @override
  State<_ManageBarbersScreen> createState() => _ManageBarbersScreenState();
}

class _ManageBarbersScreenState extends State<_ManageBarbersScreen> {
  final _inviteIdentifierCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController(text: '6500000');
  List<BarberEntity> _barbers = [];

  String? _inviteError;
  String? _salaryError;

  @override
  void initState() {
    super.initState();
    _loadBarbers();
  }

  @override
  void dispose() {
    _inviteIdentifierCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBarbers() async {
    final res = await sl<ShopRepository>().getShopBarbers(widget.shop.id);
    if (mounted) {
      setState(() => _barbers = res.data ?? []);
    }
  }

  Future<void> _inviteBarber() async {
    final identifier = _inviteIdentifierCtrl.text.trim();
    final parsedSalary = int.tryParse(_salaryCtrl.text.trim());

    String? inviteErr;
    if (identifier.isEmpty) {
      inviteErr = 'Vui lòng nhập Email hoặc Số điện thoại của ứng viên';
    } else if (!identifier.contains('@')) {
      inviteErr = AppFormatters.validateVietnamPhone(identifier);
    }

    setState(() {
      _inviteError = inviteErr;
      _salaryError = (parsedSalary == null || parsedSalary <= 0)
          ? 'Lương cứng đề xuất phải là số nguyên lớn hơn 0'
          : null;
    });

    if (_inviteError != null || _salaryError != null) return;

    final cs = context.colorScheme;
    final manager = context.read<AuthCubit>().state.user;
    if (manager == null) return;
    final res = await sl<BarberRepository>().inviteBarberToShop(
      managerId: manager.id,
      shopId: widget.shop.id,
      emailOrPhone: identifier,
      baseSalary: parsedSalary!,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => setState(() => _inviteError = f.message),
      onSuccess: (_) {
        _inviteIdentifierCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: const Text(
              'Đã gửi lời mời làm Barber thành công! Thông báo đã gửi tới ứng viên.',
            ),
          ),
        );
      },
    );
  }

  void _editSalary(BarberEntity barber) {
    final ctrl = TextEditingController(text: barber.baseSalary.toString());
    String? salaryError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Lương cứng: ${barber.fullName}'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (salaryError != null) {
                setModalState(() => salaryError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Lương cứng (VNĐ/tháng) *',
              errorText: salaryError,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final parsed = int.tryParse(ctrl.text.trim());
                if (parsed == null || parsed < 0) {
                  setModalState(() {
                    salaryError = 'Vui lòng nhập mức lương cứng hợp lệ (>= 0)';
                  });
                  return;
                }
                await sl<BarberRepository>().updateBarberBaseSalary(
                  barberId: barber.id,
                  baseSalary: parsed,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadBarbers();
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveBarber(BarberEntity barber) async {
    final cs = context.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá Barber khỏi quán?'),
        content: Text(
          'Bạn có chắc chắn muốn xoá Barber "${barber.fullName}" khỏi quán không? Tài khoản này sẽ chuyển về vai trò Khách hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá Barber'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await sl<BarberRepository>().removeBarberFromShop(
      barberId: barber.id,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: cs.error, content: Text(f.message)),
      ),
      onSuccess: (_) {
        _loadBarbers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text('Đã xoá Barber "${barber.fullName}" khỏi quán!'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Barber')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mời nhân sự làm Barber (Theo Email hoặc SĐT)',
                  style: tt.cardTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  'Gợi ý thử nghiệm: nhập `khachmoi@barbersmart.vn` (hợp lệ) hoặc `barber2_1@barbersmart.vn` (báo lỗi do đã thuộc quán khác).',
                  style: tt.bodySmallMuted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inviteIdentifierCtrl,
                  onChanged: (_) {
                    if (_inviteError != null) {
                      setState(() => _inviteError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Nhập Email hoặc Số điện thoại',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    errorText: _inviteError,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_salaryError != null) {
                      setState(() => _salaryError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Lương cứng đề xuất (VNĐ)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    errorText: _salaryError,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _inviteBarber,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Gửi lời mời làm Barber'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đội ngũ Barber hiện tại (${_barbers.length})',
            style: tt.sectionTitle,
          ),
          const SizedBox(height: 10),
          ..._barbers.map(
            (b) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: appColors.cardShadow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    backgroundImage:
                        b.avatarUrl != null ? NetworkImage(b.avatarUrl!) : null,
                    child: b.avatarUrl == null
                        ? Icon(Icons.person, color: cs.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.fullName,
                          style: tt.bodyStrong,
                        ),
                        Text(
                          'Lương cứng: ${AppFormatters.formatVnd(b.baseSalary)} + 10% hoa hồng',
                          style: tt.bodySmallMuted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chỉnh lương cứng',
                    icon: Icon(
                      Icons.edit_outlined,
                      color: cs.primary,
                    ),
                    onPressed: () => _editSalary(b),
                  ),
                  IconButton(
                    tooltip: 'Xoá Barber khỏi quán',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: cs.error,
                    ),
                    onPressed: () => _confirmRemoveBarber(b),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình Tư vấn khách hàng dành cho Chủ quán (Role MANAGER):
/// Hiển thị danh sách tất cả các cuộc hội thoại khách hàng nhắn cho quán.
class _ManagerChatListScreen extends StatefulWidget {
  final ShopEntity shop;
  final String? initialRoomId;
  final String? initialCustomerHint;

  const _ManagerChatListScreen({
    required this.shop,
    this.initialRoomId,
    this.initialCustomerHint,
  });

  @override
  State<_ManagerChatListScreen> createState() => _ManagerChatListScreenState();
}

class _ManagerChatListScreenState extends State<_ManagerChatListScreen> {
  List<ChatRoomEntity> _rooms = [];
  bool _loading = true;
  bool _didAutoOpenInitialRoom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res =
        await sl<SocialRepository>().getManagerShopChatRooms(widget.shop.id);
    if (mounted) {
      final loaded = res.data ?? [];
      setState(() {
        _rooms = loaded;
        _loading = false;
      });

      if (!_didAutoOpenInitialRoom) {
        _didAutoOpenInitialRoom = true;
        final wantedId = (widget.initialRoomId ?? '').trim();
        final hint = (widget.initialCustomerHint ?? '').trim().toLowerCase();
        ChatRoomEntity? target;
        if (wantedId.isNotEmpty) {
          for (final r in loaded) {
            if (r.id == wantedId) {
              target = r;
              break;
            }
          }
        }
        if (target == null && hint.isNotEmpty) {
          for (final r in loaded) {
            if (r.customerName.isNotEmpty &&
                hint.contains(r.customerName.toLowerCase())) {
              target = r;
              break;
            }
          }
        }
        if (target == null &&
            (wantedId.isNotEmpty || hint.isNotEmpty) &&
            loaded.isNotEmpty) {
          target = loaded.first;
        }
        if (target != null) {
          final roomIdToOpen = target.id;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await context.push('/chat/$roomIdToOpen');
            if (mounted) _load();
          });
        } else if (wantedId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await context.push('/chat/$wantedId');
            if (mounted) _load();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Tư vấn khách hàng (Chat với quán)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có cuộc hội thoại tư vấn khách hàng nào.',
                    style: tt.bodyMuted,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final room = _rooms[i];
                    final lastMsg = room.messages.isNotEmpty
                        ? room.messages.last.content
                        : 'Chưa có tin nhắn';
                    return Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: appColors.cardShadow,
                      ),
                      child: ListTile(
                        onTap: () async {
                          await context.push('/chat/${room.id}');
                          if (mounted) _load();
                        },
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(
                            Icons.forum_outlined,
                            color: cs.primary,
                          ),
                        ),
                        title: Text(
                          'Khách hàng: ${room.customerName}',
                          style: tt.bodyStrong,
                        ),
                        subtitle: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmallMuted,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ShopRevenuePayrollScreen extends StatefulWidget {
  final ShopEntity shop;
  const _ShopRevenuePayrollScreen({required this.shop});

  @override
  State<_ShopRevenuePayrollScreen> createState() =>
      _ShopRevenuePayrollScreenState();
}

class _ShopRevenuePayrollScreenState extends State<_ShopRevenuePayrollScreen> {
  ShopRevenueSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res =
        await sl<ShopRepository>().getShopRevenueAndPayroll(widget.shop.id);
    if (mounted) {
      setState(() => _summary = res.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Doanh thu & Bảng lương')),
      body: _summary == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng doanh thu thực thu (Chỉ tính lịch COMPLETED)',
                        style: tt.bodySmallOnPrimary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormatters.formatVnd(_summary!.totalShopRevenue),
                        style: tt.heroPriceOnPrimary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Số đơn hoàn thành: ${_summary!.completedBookingCount} đơn • Tổng quỹ lương & hoa hồng: ${AppFormatters.formatVnd(_summary!.totalBarberPayout)}',
                        style: tt.bodySmallOnPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bảng lương chi tiết từng Barber (Lương cứng + 10% Hoa hồng)',
                  style: tt.sectionTitle,
                ),
                const SizedBox(height: 10),
                ..._summary!.barberPayrolls.map(
                  (p) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: appColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.barberName,
                                style: tt.cardTitle,
                              ),
                            ),
                            Text(
                              AppFormatters.formatVnd(p.totalPayout),
                              style: tt.pricePrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khách hoàn thành: ${p.completedCustomerCount} • Doanh thu tạo ra: ${AppFormatters.formatVnd(p.generatedRevenue)}',
                          style: tt.bodySmallMuted,
                        ),
                        Text(
                          'Lương cứng: ${AppFormatters.formatVnd(p.baseSalary)} + Hoa hồng (10%): ${AppFormatters.formatVnd(p.commissionAmount)}',
                          style: tt.bodyRegular,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
