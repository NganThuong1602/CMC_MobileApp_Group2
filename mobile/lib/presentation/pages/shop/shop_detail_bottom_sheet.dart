import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Bottom Sheet Chi tiết quán chuẩn Pixel-perfect theo Ảnh 4:
/// - Thanh kéo trên cùng (drag handle)
/// - Ảnh vuông bo góc + Tên, Địa chỉ, Giờ mở cửa + Nút pill viền xanh `Chỉ đường`
/// - Nút full-width xanh lá `Chat với barber` (tích hợp Socket.IO Group Chat)
/// - 5 Tab: `Thông tin`, `Dịch vụ`, `Hình ảnh`, `Barber`, `Đánh giá`
class ShopDetailBottomSheet extends StatefulWidget {
  final ShopEntity shop;
  final VoidCallback? onDirectionsTap;

  const ShopDetailBottomSheet({
    super.key,
    required this.shop,
    this.onDirectionsTap,
  });

  static Future<void> show(
    BuildContext context, {
    required ShopEntity shop,
    VoidCallback? onDirectionsTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopDetailBottomSheet(
        shop: shop,
        onDirectionsTap: onDirectionsTap,
      ),
    );
  }

  @override
  State<ShopDetailBottomSheet> createState() => _ShopDetailBottomSheetState();
}

class _ShopDetailBottomSheetState extends State<ShopDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<ServiceEntity> _services = [];
  List<BarberEntity> _barbers = [];
  List<ReviewEntity> _reviews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final sRes = await sl<ShopRepository>().getShopServices(widget.shop.id);
    final bRes = await sl<ShopRepository>().getShopBarbers(widget.shop.id);
    final rRes = await sl<SocialRepository>().getShopReviews(widget.shop.id);
    if (mounted) {
      setState(() {
        _services = sRes.data ?? [];
        _barbers = bRes.data ?? [];
        _reviews = rRes.data ?? [];
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBooking({String? barberId}) {
    Navigator.of(context).pop();
    final query = barberId != null ? '?barberId=$barberId' : '';
    context.push('/booking/${widget.shop.id}$query');
  }

  Future<void> _openGroupChat() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final roomRes = await sl<SocialRepository>().getOrCreateShopChatRoom(
      shopId: widget.shop.id,
      customerId: user.id,
    );
    if (!mounted) return;
    roomRes.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      onSuccess: (room) {
        Navigator.of(context).pop();
        context.push('/chat/${room.id}');
      },
    );
  }

  void _showWriteReviewDialog() {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    int selectedStars = 5;
    final commentCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Đánh giá quán'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setModalState(() => selectedStars = i + 1),
                    icon: Icon(
                      i < selectedStars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFB300),
                      size: 30,
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Chia sẻ trải nghiệm cắt tóc của bạn...',
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
                await sl<SocialRepository>().addShopReview(
                  shopId: widget.shop.id,
                  userId: user.id,
                  rating: selectedStars,
                  comment: commentCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDetails();
              },
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.93,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6DCE5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.shop.coverImageUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 76,
                              height: 76,
                              color: AppTheme.primaryGreenLight,
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: AppTheme.primaryGreen,
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
                                widget.shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.shop.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.shop.openTime} - ${widget.shop.closeTime}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onDirectionsTap?.call();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreenLight,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.near_me_rounded,
                                        size: 13,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Chỉ đường',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: ElevatedButton.icon(
                            onPressed: _openGroupChat,
                            icon: const Icon(Icons.forum_rounded, size: 18),
                            label: const Text('Chat với barber'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: OutlinedButton.icon(
                            onPressed: () => _openBooking(),
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Đặt lịch',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primaryGreen,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Thông tin'),
                  Tab(text: 'Dịch vụ'),
                  Tab(text: 'Hình ảnh'),
                  Tab(text: 'Barber'),
                  Tab(text: 'Đánh giá'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(scrollCtrl),
                    _buildServicesTab(scrollCtrl),
                    _buildGalleryTab(scrollCtrl),
                    _buildBarbersTab(scrollCtrl),
                    _buildReviewsTab(scrollCtrl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 17,
                    color: AppTheme.primaryGreen,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Giới thiệu ngắn gọn:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.shop.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF555E68),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.phone_in_talk_rounded,
            color: AppTheme.primaryGreen,
          ),
          title: const Text('Hotline đặt lịch'),
          subtitle: Text(widget.shop.phone),
        ),
      ],
    );
  }

  Widget _buildServicesTab(ScrollController ctrl) {
    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = _services[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thời gian dự kiến: ${s.durationMinutes} phút',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.formatVnd(s.price),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGalleryTab(ScrollController ctrl) {
    final imgs = widget.shop.galleryUrls.isNotEmpty
        ? widget.shop.galleryUrls
        : [widget.shop.coverImageUrl];
    return GridView.builder(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: imgs.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(imgs[i], fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildBarbersTab(ScrollController ctrl) {
    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      itemCount: _barbers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final b = _barbers[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      b.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _openBooking(barberId: b.id),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('Chọn thợ', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _showWriteReviewDialog,
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: const Text('Viết đánh giá của bạn'),
        ),
        const SizedBox(height: 12),
        ..._reviews.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        r.rating,
                        (_) => const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFFB300),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.comment,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

