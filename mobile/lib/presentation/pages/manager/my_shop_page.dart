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
import '../../../domain/repositories/barber_repository.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';
import '../../widgets/image_picker_widgets.dart';
import '../../widgets/sepay_qr_dialog.dart';

/// Màn hình Quản lý quán (Role MANAGER) chuẩn Pixel-perfect theo Ảnh 9:
/// - Ảnh cover bo góc có gradient đen đáy, hiển thị Tên quán + Giờ mở cửa + SĐT đè lên ảnh.
/// - 3 Card menu trắng bo góc:
///   1. `Quản lý thông tin` (Sửa thông tin quán, CRUD Dịch vụ, Mua gói Nổi bật SePay 20k/50k/90k)
///   2. `Quản lý barber` (Tìm Email/SĐT mời làm Barber, chặn nếu đã thuộc quán khác, chỉnh lương cứng)
///   3. `Doanh thu và lương` (Chỉ cộng doanh thu & 10% hoa hồng từ lịch COMPLETED)
class MyShopPage extends StatefulWidget {
  const MyShopPage({super.key});

  @override
  State<MyShopPage> createState() => _MyShopPageState();
}

class _MyShopPageState extends State<MyShopPage> {
  ShopEntity? _shop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShop();
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

  void _openManageBarbersScreen(ShopEntity shop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ManageBarbersScreen(shop: shop),
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
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : _shop == null
                      ? const Center(
                          child: Text('Bạn chưa sở hữu cửa hàng nào.'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Banner Cover chuẩn Ảnh 9
                            Container(
                              height: 196,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: AppTheme.softCardShadow,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _shop!.coverImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.08),
                                          Colors.black.withValues(alpha: 0.78),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 15,
                                              color: Color(0xFF4ADE80),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${_shop!.openTime} - ${_shop!.closeTime}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 15,
                                              color: Color(0xFF4ADE80),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _shop!.phone,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                              ),
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
                              icon: Icons.storefront_outlined,
                              title: 'Quản lý thông tin',
                              onTap: () => _openManageInfoSheet(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
                              icon: Icons.badge_outlined,
                              title: 'Quản lý barber',
                              onTap: () => _openManageBarbersScreen(_shop!),
                            ),
                            const SizedBox(height: 12),
                            _buildManagerMenuCard(
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
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
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
  List<ServiceEntity> _services = [];
  late String _coverImageUrl;
  late List<String> _galleryUrls;

  @override
  void initState() {
    super.initState();
    _coverImageUrl = widget.shop.coverImageUrl;
    _galleryUrls = List<String>.from(widget.shop.galleryUrls);
    _loadServices();
  }

  Future<void> _loadServices() async {
    final res = await sl<ShopRepository>().getShopServices(widget.shop.id);
    if (mounted) {
      setState(() => _services = res.data ?? []);
    }
  }

  Future<void> _buyHighlight(HighlightPackageType pkg) async {
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
        SnackBar(content: Text(f.message)),
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
              backgroundColor: AppTheme.primaryGreen,
              content: Text('Đã kích hoạt ${pkg.label} thành công!'),
            ),
          );
        }
      },
    );
  }

  void _showAddServiceDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '100000');
    final durCtrl = TextEditingController(text: '30');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm dịch vụ mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên dịch vụ'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá (VNĐ)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
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
              await sl<ShopRepository>().upsertService(
                shopId: widget.shop.id,
                name: nameCtrl.text,
                price: int.tryParse(priceCtrl.text) ?? 100000,
                durationMinutes: int.tryParse(durCtrl.text) ?? 30,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadServices();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thông tin & Nổi bật')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Mua gói Nổi bật tự động qua SePay',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppFormatters.formatVnd(pkg.priceVnd),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thông tin cửa hàng',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên quán'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.addrCtrl,
            decoration: const InputDecoration(labelText: 'Địa chỉ'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.openCtrl,
                  decoration: const InputDecoration(labelText: 'Giờ mở cửa'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.closeCtrl,
                  decoration: const InputDecoration(labelText: 'Giờ đóng cửa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.phoneCtrl,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
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
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              await sl<ShopRepository>().updateShopInfo(
                shopId: widget.shop.id,
                name: widget.nameCtrl.text,
                address: widget.addrCtrl.text,
                phone: widget.phoneCtrl.text,
                description: widget.descCtrl.text,
                openTime: widget.openCtrl.text,
                closeTime: widget.closeCtrl.text,
                coverImageUrl: _coverImageUrl.trim().isNotEmpty
                    ? _coverImageUrl.trim()
                    : widget.shop.coverImageUrl,
                galleryUrls: _galleryUrls,
              );
              widget.onUpdated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.primaryGreen,
                    content: Text('Đã lưu thông tin & hình ảnh quán!'),
                  ),
                );
              }
            },
            child: const Text('Lưu cập nhật thông tin'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách dịch vụ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _showAddServiceDialog,
                icon: const Icon(Icons.add),
                label: const Text('Thêm dịch vụ'),
              ),
            ],
          ),
          ..._services.map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${s.durationMinutes} phút • ${AppFormatters.formatVnd(s.price)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed),
                onPressed: () async {
                  await sl<ShopRepository>().deleteService(
                    shopId: widget.shop.id,
                    serviceId: s.id,
                  );
                  _loadServices();
                },
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
    final manager = context.read<AuthCubit>().state.user;
    if (manager == null) return;
    final res = await sl<BarberRepository>().inviteBarberToShop(
      managerId: manager.id,
      shopId: widget.shop.id,
      emailOrPhone: _inviteIdentifierCtrl.text,
      baseSalary: int.tryParse(_salaryCtrl.text) ?? 6500000,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: AppTheme.dangerRed),
      ),
      onSuccess: (_) {
        _inviteIdentifierCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('Đã gửi lời mời làm Barber thành công!'),
          ),
        );
      },
    );
  }

  void _editSalary(BarberEntity barber) {
    final ctrl = TextEditingController(text: barber.baseSalary.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lương cứng: ${barber.fullName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Lương cứng (VNĐ/tháng)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await sl<BarberRepository>().updateBarberBaseSalary(
                barberId: barber.id,
                baseSalary: int.tryParse(ctrl.text) ?? barber.baseSalary,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadBarbers();
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Barber')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mời nhân sự làm Barber (Theo Email hoặc SĐT)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gợi ý thử nghiệm: nhập `newbarber@barbersmart.vn` (hợp lệ) hoặc `otherbarber@barbersmart.vn` (báo lỗi do đã thuộc quán khác).',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inviteIdentifierCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập Email hoặc Số điện thoại',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lương cứng đề xuất (VNĐ)',
                    prefixIcon: Icon(Icons.payments_outlined),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ..._barbers.map(
            (b) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.softCardShadow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGreenLight,
                    backgroundImage:
                        b.avatarUrl != null ? NetworkImage(b.avatarUrl!) : null,
                    child: b.avatarUrl == null
                        ? const Icon(Icons.person, color: AppTheme.primaryGreen)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Lương cứng: ${AppFormatters.formatVnd(b.baseSalary)} + 10% hoa hồng',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryGreen,
                    ),
                    onPressed: () => _editSalary(b),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Doanh thu & Bảng lương')),
      body: _summary == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng doanh thu thực thu (Chỉ tính lịch COMPLETED)',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormatters.formatVnd(_summary!.totalShopRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Số đơn hoàn thành: ${_summary!.completedBookingCount} đơn • Tổng quỹ lương & hoa hồng: ${AppFormatters.formatVnd(_summary!.totalBarberPayout)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bảng lương chi tiết từng Barber (Lương cứng + 10% Hoa hồng)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ..._summary!.barberPayrolls.map(
                  (p) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.softCardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.barberName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              AppFormatters.formatVnd(p.totalPayout),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGreen,
                                fontSize: 15.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khách hoàn thành: ${p.completedCustomerCount} • Doanh thu tạo ra: ${AppFormatters.formatVnd(p.generatedRevenue)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          'Lương cứng: ${AppFormatters.formatVnd(p.baseSalary)} + Hoa hồng (10%): ${AppFormatters.formatVnd(p.commissionAmount)}',
                          style: const TextStyle(fontSize: 12.5),
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

