import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/finance_entities.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Trung tâm Quản trị Hệ thống (Role ADMIN):
/// Giao diện đồng bộ với trang Quản lý của Manager, bao gồm:
/// 1. Duyệt yêu cầu mở quán ("Chờ duyệt"): Xem chi tiết đầy đủ, Phê duyệt hoặc Từ chối.
/// 2. Quản lý Mã giảm giá tự động áp dụng cho quán Gói Hợp tác.
/// 3. Quản lý danh sách quán toàn hệ thống: Xem chi tiết và Xoá quán bất kỳ.
class AdminHubPage extends StatefulWidget {
  final bool isActiveTab;
  final String? navigationToken;

  const AdminHubPage({
    super.key,
    this.isActiveTab = false,
    this.navigationToken,
  });

  @override
  State<AdminHubPage> createState() => _AdminHubPageState();
}

class _AdminHubPageState extends State<AdminHubPage> {
  List<ShopEntity> _pendingShops = [];
  List<ShopEntity> _activeShops = [];
  bool _loading = true;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    _lastToken = widget.navigationToken;
    _loadAdminData();
  }

  @override
  void didUpdateWidget(covariant AdminHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isActiveTab && !oldWidget.isActiveTab) ||
        (widget.navigationToken != null &&
            widget.navigationToken != _lastToken)) {
      final tokenChanged =
          widget.navigationToken != null && widget.navigationToken != _lastToken;
      _lastToken = widget.navigationToken;
      _loadAdminData().then((_) {
        if (tokenChanged && mounted && _pendingShops.isNotEmpty) {
          _openPendingApprovalScreen();
        }
      });
    }
  }

  Future<void> _loadAdminData() async {
    setState(() => _loading = true);
    final pendingRes = await sl<ShopRepository>().getAdminPendingShops();
    final activeRes = await sl<ShopRepository>().getAdminActiveShops();
    if (!mounted) return;
    setState(() {
      _pendingShops = pendingRes.data ?? [];
      _activeShops = activeRes.data ?? [];
      _loading = false;
    });
  }

  void _openPendingApprovalScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminPendingShopsScreen(
          onChanged: () {
            _loadAdminData();
            context.read<ShopDiscoveryCubit>().loadAll();
          },
        ),
      ),
    );
  }

  void _openActiveShopsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminActiveShopsScreen(
          onChanged: () {
            _loadAdminData();
            context.read<ShopDiscoveryCubit>().loadAll();
          },
        ),
      ),
    );
  }

  void _openDiscountsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminDiscountsScreen(
          onChanged: () {
            _loadAdminData();
            context.read<ShopDiscoveryCubit>().loadAll();
          },
        ),
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
                  _loadAdminData();
                }
              },
              onProfileSocialTap: () => context.push('/profile-social'),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadAdminData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            height: 186,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: appColors.cardShadow,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1000&q=80',
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'ADMIN HỆ THỐNG',
                                          style: tt.badgeOnPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Trung tâm Quản trị BarberSmart',
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
                                                Icons.pending_actions_rounded,
                                                size: 15,
                                                color: cs.secondary,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Chờ duyệt: ${_pendingShops.length} quán',
                                                style: tt.bodySmallOnInverse,
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.storefront_rounded,
                                                size: 15,
                                                color: cs.secondary,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Đang hoạt động: ${_activeShops.length} quán',
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
                          _buildAdminMenuCard(
                            context: context,
                            icon: Icons.verified_outlined,
                            title: 'Duyệt mở quán (Chờ duyệt)',
                            subtitle: _pendingShops.isEmpty
                                ? 'Hiện không có yêu cầu mở quán nào chờ duyệt'
                                : 'Có ${_pendingShops.length} yêu cầu mở quán đang chờ Admin phê duyệt',
                            badgeCount: _pendingShops.length,
                            onTap: _openPendingApprovalScreen,
                          ),
                          const SizedBox(height: 12),
                          _buildAdminMenuCard(
                            context: context,
                            icon: Icons.local_offer_outlined,
                            title: 'Thêm mã giảm giá',
                            subtitle:
                                'Tạo & quản lý ưu đãi tự động áp dụng cho quán Gói Hợp tác',
                            onTap: _openDiscountsScreen,
                          ),
                          const SizedBox(height: 12),
                          _buildAdminMenuCard(
                            context: context,
                            icon: Icons.store_mall_directory_outlined,
                            title: 'Quản lý danh sách quán',
                            subtitle:
                                'Tổng cộng ${_activeShops.length} quán đang hoạt động • Kiểm tra & xoá quán',
                            onTap: _openActiveShopsScreen,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badgeCount = 0,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodySmallMuted,
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.warningContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badgeCount chờ duyệt',
                    style: tt.badgePrimary,
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

class _AdminPendingShopsScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const _AdminPendingShopsScreen({required this.onChanged});

  @override
  State<_AdminPendingShopsScreen> createState() =>
      _AdminPendingShopsScreenState();
}

class _AdminPendingShopsScreenState extends State<_AdminPendingShopsScreen> {
  List<ShopEntity> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await sl<ShopRepository>().getAdminPendingShops();
    if (!mounted) return;
    setState(() {
      _pending = res.data ?? [];
      _loading = false;
    });
  }

  Future<void> _approve(ShopEntity shop) async {
    final cs = context.colorScheme;
    final res = await sl<ShopRepository>().approveShopByAdmin(shop.id);
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: cs.error, content: Text(f.message)),
      ),
      onSuccess: (_) {
        widget.onChanged();
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text(
              'Đã phê duyệt quán "${shop.name}"! Chủ quán đã được nâng lên Quản lý.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _reject(ShopEntity shop) async {
    final cs = context.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu mở quán?'),
        content: Text(
          'Bạn có chắc chắn muốn từ chối yêu cầu đăng ký quán "${shop.name}" không?',
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
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await sl<ShopRepository>().deleteShopByAdmin(shop.id);
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: cs.error, content: Text(f.message)),
      ),
      onSuccess: (_) {
        widget.onChanged();
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text('Đã từ chối yêu cầu mở quán "${shop.name}".'),
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
      appBar: AppBar(
        title: const Text('Duyệt mở quán (Chờ duyệt)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Hiện không có yêu cầu đăng ký mở quán nào đang chờ duyệt.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMuted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final shop = _pending[i];
                    return InkWell(
                      onTap: () => _showPendingShopDetailSheet(shop),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: appColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    shop.coverImageUrl,
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 68,
                                      height: 68,
                                      color: cs.primaryContainer,
                                      child: Icon(
                                        Icons.storefront_rounded,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              shop.name,
                                              style: tt.cardTitle,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: appColors.warningContainer,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Chờ duyệt',
                                              style: tt.badgeWarning,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        shop.address,
                                        style: tt.bodySmallMuted,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SĐT quán: ${shop.phone} • Giờ mở cửa: ${shop.openTime} - ${shop.closeTime}',
                                        style: tt.bodySmallMuted,
                                      ),
                                      if (shop.subscriptionPlan != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Gói: ${shop.subscriptionPlan!.label}'
                                          '${shop.paymentAmount > 0 ? ' (${AppFormatters.formatVnd(shop.paymentAmount)})' : ''}',
                                          style: tt.bodySmallPrimary,
                                        ),
                                      ],
                                      if (shop.ownerName.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Người đăng ký: ${shop.ownerName} (${shop.ownerEmail})',
                                          style: tt.captionMuted,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (shop.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                shop.description,
                                style: tt.bodyRegular,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _showPendingShopDetailSheet(shop),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Xem đầy đủ hồ sơ & vị trí bản đồ',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reject(shop),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: cs.error,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Từ chối',
                                      style: tt.buttonLabelDanger,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approve(shop),
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Duyệt mở quán'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showPendingShopDetailSheet(ShopEntity shop) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final ac = context.appColors;
    final center = LatLng(shop.latitude, shop.longitude);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chi tiết hồ sơ đăng ký quán',
                          style: tt.dialogTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          shop.coverImageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: cs.primaryContainer,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 48,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(shop.name, style: tt.pageTitle),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ac.warningContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Chờ duyệt', style: tt.badgeWarning),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailItem(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Gói đăng ký',
                        value: shop.subscriptionPlan?.label ??
                            (shop.isCooperation
                                ? 'Gói Hợp tác'
                                : 'Gói Thành viên'),
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.payments_outlined,
                        label: 'Thông tin thanh toán SePay',
                        value: [
                          if (shop.paymentAmount > 0)
                            AppFormatters.formatVnd(shop.paymentAmount),
                          if (shop.paymentCode.isNotEmpty)
                            'Mã GD: ${shop.paymentCode}',
                          if (shop.paidAt != null)
                            'Thanh toán lúc: ${AppFormatters.formatDateDdMmYyyy(shop.paidAt!)}',
                        ].join(' • ').isEmpty
                            ? 'Đã xác nhận thanh toán'
                            : [
                                if (shop.paymentAmount > 0)
                                  AppFormatters.formatVnd(shop.paymentAmount),
                                if (shop.paymentCode.isNotEmpty)
                                  'Mã GD: ${shop.paymentCode}',
                                if (shop.paidAt != null)
                                  AppFormatters.formatDateDdMmYyyy(shop.paidAt!),
                              ].join(' • '),
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.location_on_outlined,
                        label: 'Địa chỉ chi tiết',
                        value: shop.address,
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại liên hệ',
                        value: shop.phone,
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.schedule_rounded,
                        label: 'Giờ hoạt động',
                        value: '${shop.openTime} - ${shop.closeTime}',
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.description_outlined,
                        label: 'Mô tả cửa hàng',
                        value: shop.description.trim().isEmpty
                            ? 'Chưa cập nhật mô tả'
                            : shop.description,
                        tt: tt,
                        cs: cs,
                      ),
                      _buildDetailItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Tài khoản đăng ký',
                        value: [
                          if (shop.ownerName.isNotEmpty) shop.ownerName,
                          if (shop.ownerEmail.isNotEmpty) shop.ownerEmail,
                          if (shop.ownerPhone.isNotEmpty) shop.ownerPhone,
                        ].join(' • '),
                        tt: tt,
                        cs: cs,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vị trí đã ghim trên bản đồ OpenStreetMap',
                        style: tt.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tọa độ: ${shop.latitude.toStringAsFixed(5)}, ${shop.longitude.toStringAsFixed(5)}',
                        style: tt.captionMuted,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 190,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: AppConstants.osmTileUrl,
                                userAgentPackageName:
                                    AppConstants.osmUserAgentPackage,
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: center,
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      size: 40,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _reject(shop);
                          },
                          icon: Icon(Icons.close_rounded, color: cs.error),
                          label: Text('Từ chối', style: tt.buttonLabelDanger),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _approve(shop);
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Duyệt mở quán'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required AppTextStyles tt,
    required ColorScheme cs,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.captionMuted),
                const SizedBox(height: 2),
                Text(value, style: tt.bodyRegular),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActiveShopsScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const _AdminActiveShopsScreen({required this.onChanged});

  @override
  State<_AdminActiveShopsScreen> createState() =>
      _AdminActiveShopsScreenState();
}

class _AdminActiveShopsScreenState extends State<_AdminActiveShopsScreen> {
  List<ShopEntity> _shops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await sl<ShopRepository>().getAdminActiveShops();
    if (!mounted) return;
    setState(() {
      _shops = res.data ?? [];
      _loading = false;
    });
  }

  Future<void> _confirmDeleteShop(ShopEntity shop) async {
    final cs = context.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá quán khỏi hệ thống?'),
        content: Text(
          'Bạn có chắc chắn muốn xoá quán "${shop.name}" không? Chủ quán và các Barber thuộc quán sẽ chuyển về vai trò Khách hàng.',
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
            child: const Text('Xoá quán'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await sl<ShopRepository>().deleteShopByAdmin(shop.id);
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: cs.error, content: Text(f.message)),
      ),
      onSuccess: (_) {
        widget.onChanged();
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text('Đã xoá quán "${shop.name}" khỏi hệ thống!'),
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
      appBar: AppBar(
        title: Text('Danh sách quán (${_shops.length})'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shops.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có quán nào đang hoạt động.',
                    style: tt.bodyMuted,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final shop = _shops[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: appColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              shop.coverImageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: cs.primaryContainer,
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop.name,
                                  style: tt.cardTitle,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  shop.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmallMuted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  shop.hasRating
                                      ? 'SĐT: ${shop.phone} • ★ ${shop.rating.toStringAsFixed(1)}'
                                      : 'SĐT: ${shop.phone}',
                                  style: tt.bodySmallPrimary,
                                ),
                                if (shop.ownerName.isNotEmpty)
                                  Text(
                                    'Chủ quán: ${shop.ownerName}',
                                    style: tt.captionMuted,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Xoá quán khỏi hệ thống',
                            onPressed: () => _confirmDeleteShop(shop),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AdminDiscountsScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const _AdminDiscountsScreen({required this.onChanged});

  @override
  State<_AdminDiscountsScreen> createState() => _AdminDiscountsScreenState();
}

class _AdminDiscountsScreenState extends State<_AdminDiscountsScreen> {
  List<DiscountCodeEntity> _discounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await sl<ShopRepository>().getDiscountCodes();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _discounts = res.data ?? [];
    });
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m • ${AppFormatters.formatDateDdMmYyyy(dt)}';
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _openCreateDiscountModal() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final percentCtrl = TextEditingController(text: '15');
    DateTime startAt = DateTime.now();
    DateTime endAt = DateTime.now().add(const Duration(days: 7));
    String? nameError;
    String? percentError;
    String? dateError;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = ctx.colorScheme;
            final tt = ctx.appTextStyles;
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              final code = codeCtrl.text.trim();
              final pct = int.tryParse(percentCtrl.text.trim());

              String? nextNameErr;
              String? nextPctErr;
              String? nextDateErr;

              if (name.isEmpty) {
                nextNameErr = 'Vui lòng nhập tên chương trình giảm giá.';
              }
              if (pct == null || pct < 1 || pct > 90) {
                nextPctErr = 'Phần trăm giảm giá phải từ 1% đến 90%.';
              }
              if (!endAt.isAfter(startAt)) {
                nextDateErr =
                    'Thời gian kết thúc phải sau thời gian bắt đầu.';
              }

              setSheetState(() {
                nameError = nextNameErr;
                percentError = nextPctErr;
                dateError = nextDateErr;
              });

              if (nextNameErr != null ||
                  nextPctErr != null ||
                  nextDateErr != null) {
                return;
              }

              setSheetState(() => saving = true);
              final res = await sl<ShopRepository>().createDiscountCode(
                name: name,
                code: code.isEmpty ? null : code.toUpperCase(),
                discountPercent: pct!,
                startAt: startAt,
                endAt: endAt,
              );
              if (!ctx.mounted) return;
              setSheetState(() => saving = false);

              res.fold(
                onFailure: (f) {
                  setSheetState(() => dateError = f.message);
                },
                onSuccess: (_) {
                  Navigator.pop(sheetCtx);
                  _load();
                  widget.onChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: cs.primary,
                      content: const Text(
                        'Đã tạo mã giảm giá & tự động áp dụng cho các quán Gói Hợp tác!',
                      ),
                    ),
                  );
                },
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thêm mã giảm giá hệ thống',
                            style: tt.dialogTitle,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      'Mã đang hiệu lực sẽ tự động áp dụng cho toàn bộ quán đang dùng Gói Hợp tác.',
                      style: tt.bodySmallMuted,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên chương trình giảm giá *',
                        hintText: 'VD: Ưu đãi Cuối tuần Vàng',
                        prefixIcon: const Icon(Icons.campaign_outlined),
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Mã code (tùy chọn)',
                              hintText: 'VD: VIP15',
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: percentCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Giảm (%) *',
                              hintText: '1-90',
                              suffixText: '%',
                              errorText: percentError,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Thời gian bắt đầu', style: tt.bodySmallStrong),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickDateTime(startAt);
                        if (picked != null && ctx.mounted) {
                          setSheetState(() {
                            startAt = picked;
                            dateError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_formatDateTime(startAt)),
                    ),
                    const SizedBox(height: 10),
                    Text('Thời gian kết thúc', style: tt.bodySmallStrong),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickDateTime(endAt);
                        if (picked != null && ctx.mounted) {
                          setSheetState(() {
                            endAt = picked;
                            dateError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(_formatDateTime(endAt)),
                    ),
                    if (dateError != null) ...[
                      const SizedBox(height: 6),
                      Text(dateError!, style: tt.bodySmallDanger),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Lưu & Áp dụng cho quán Hợp tác'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(DiscountCodeEntity discount) async {
    final cs = context.colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Xoá mã giảm giá?'),
        content: Text(
          'Bạn có chắc muốn xoá chương trình "${discount.name}" (-${discount.discountPercent}%)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await sl<ShopRepository>().deleteDiscountCode(discount.id);
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: cs.error),
      ),
      onSuccess: (_) {
        _load();
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final ac = context.appColors;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Mã giảm giá'),
        actions: [
          TextButton.icon(
            onPressed: _openCreateDiscountModal,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm mã'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDiscountModal,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm mã giảm giá'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _discounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có mã giảm giá nào.\nBấm "Thêm mã giảm giá" để tự động ưu đãi cho các quán Gói Hợp tác.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMuted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _discounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final d = _discounts[i];
                    final isActiveNow = d.isActiveAt(now);
                    final isUpcoming = d.isActive && now.isBefore(d.startAt);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: ac.cardShadow,
                        border: Border.all(
                          color: isActiveNow
                              ? cs.primary
                              : cs.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActiveNow
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '-${d.discountPercent}%',
                              style: tt.pricePrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        style: tt.cardTitle,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActiveNow
                                            ? cs.primaryContainer
                                            : isUpcoming
                                                ? ac.warningContainer
                                                : cs.errorContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isActiveNow
                                            ? 'Đang áp dụng'
                                            : isUpcoming
                                                ? 'Sắp diễn ra'
                                                : 'Hết hạn',
                                        style: isActiveNow
                                            ? tt.badgePrimary
                                            : isUpcoming
                                                ? tt.badgeWarning
                                                : tt.badgeDanger,
                                      ),
                                    ),
                                  ],
                                ),
                                if (d.code.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Mã code: ${d.code}',
                                    style: tt.bodySmallPrimary,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Từ: ${_formatDateTime(d.startAt)}',
                                  style: tt.captionMuted,
                                ),
                                Text(
                                  'Đến: ${_formatDateTime(d.endAt)}',
                                  style: tt.captionMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Áp dụng tự động cho quán dùng Gói Hợp tác',
                                  style: tt.captionMuted,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Xoá mã giảm giá',
                            onPressed: () => _confirmDelete(d),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
