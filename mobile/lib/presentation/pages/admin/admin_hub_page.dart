import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Trung tâm Quản trị Hệ thống (Role ADMIN):
/// Giao diện đồng bộ với trang Quản lý của Manager, bao gồm:
/// 1. Duyệt yêu cầu mở quán ("Chờ duyệt"): Phê duyệt (nâng cấp chủ quán lên Manager) hoặc Từ chối.
/// 2. Quản lý danh sách quán toàn hệ thống: Xem chi tiết và Xoá quán bất kỳ.
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
                    return Container(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            style: tt.badgePrimary,
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
                                    if (shop.ownerName.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Người đăng ký: ${shop.ownerName} (${shop.ownerEmail})',
                                        style: tt.bodySmallPrimary,
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
                          const SizedBox(height: 14),
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
                    );
                  },
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
                                  'SĐT: ${shop.phone} • ★ ${shop.rating}',
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
