import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Bottom Sheet Chi tiết quán chuẩn Pixel-perfect:
/// - Thanh kéo trên cùng (drag handle)
/// - Ảnh vuông bo góc + Tên, Địa chỉ, Giờ mở cửa + Nút pill viền `Chỉ đường`
/// - Nút `Chat với barber` (tích hợp Socket.IO Group Chat) & `Đặt lịch`
/// - 5 Tab: `Thông tin`, `Dịch vụ`, `Hình ảnh`, `Barber` (chạm vào Barber mở Trang cá nhân của Barber đó), `Đánh giá`
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
      backgroundColor: AppTheme.transparent,
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
    final appColors = context.appColors;
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    int selectedStars = 5;
    final commentCtrl = TextEditingController();
    String? commentError;

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
                      color: appColors.starRating,
                      size: 30,
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                onChanged: (_) {
                  if (commentError != null) {
                    setModalState(() => commentError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Chia sẻ trải nghiệm cắt tóc của bạn...',
                  errorText: commentError,
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
                if (commentCtrl.text.trim().isEmpty) {
                  setModalState(() {
                    commentError = 'Vui lòng nhập nội dung đánh giá của bạn';
                  });
                  return;
                }
                await sl<SocialRepository>().addShopReview(
                  shopId: widget.shop.id,
                  userId: user.id,
                  rating: selectedStars,
                  comment: commentCtrl.text.trim(),
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.93,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: cs.outline,
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
                                widget.shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.cardTitleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.shop.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmallMuted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.shop.openTime} - ${widget.shop.closeTime}',
                                style: tt.bodySmallMuted,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
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
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              cs.primary.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.near_me_rounded,
                                            size: 13,
                                            color: cs.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Chỉ đường',
                                            style: tt.badgePrimary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (widget.shop.hasRating)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: context.appColors.starRating,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            widget.shop.rating
                                                .toStringAsFixed(1),
                                            style: tt.captionStrong,
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (widget.shop.activeDiscountPercent > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.error,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Giảm ${widget.shop.activeDiscountPercent}%',
                                        style: tt.badgeOnPrimary,
                                      ),
                                    ),
                                ],
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
                            label: const Text('Chat với quán'),
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
                            label: const Text('Đặt lịch'),
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
                    _buildInfoTab(context, scrollCtrl),
                    _buildServicesTab(context, scrollCtrl),
                    _buildGalleryTab(scrollCtrl),
                    _buildBarbersTab(context, scrollCtrl),
                    _buildReviewsTab(context, scrollCtrl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(BuildContext context, ScrollController ctrl) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 17,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Giới thiệu ngắn gọn:',
                    style: tt.bodyStrong,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.shop.description,
                style: tt.bodyRegular,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.phone_in_talk_rounded,
            color: cs.primary,
          ),
          title: const Text('Hotline đặt lịch'),
          subtitle: Text(widget.shop.phone),
        ),
      ],
    );
  }

  Widget _buildServicesTab(BuildContext context, ScrollController ctrl) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final discountPct = widget.shop.activeDiscountPercent;

    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = _services[i];
        final discountedPrice = widget.shop.discountedPriceOf(s.price);
        final hasDiscount = discountPct > 0 && discountedPrice < s.price;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
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
                      style: tt.bodyStrong,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thời gian dự kiến: ${s.durationMinutes} phút',
                      style: tt.bodySmallMuted,
                    ),
                  ],
                ),
              ),
              if (hasDiscount)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '-$discountPct%',
                            style: tt.badgeOnPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppFormatters.formatVnd(s.price),
                          style: tt.priceStrikethrough,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.formatVnd(discountedPrice),
                      style: tt.pricePrimary,
                    ),
                  ],
                )
              else
                Text(
                  AppFormatters.formatVnd(s.price),
                  style: tt.pricePrimary,
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

  Widget _buildBarbersTab(BuildContext context, ScrollController ctrl) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

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
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/profile-social?userId=${b.userId}');
                  },
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage: b.avatarUrl != null
                                ? NetworkImage(b.avatarUrl!)
                                : null,
                            child: b.avatarUrl == null
                                ? Icon(Icons.person, color: cs.primary)
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cs.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                UserRole.barber.roleIcon,
                                size: 10,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.fullName,
                              style: tt.cardTitle,
                            ),
                            Text(
                              b.bio,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmallMuted,
                            ),
                            Text(
                              'Xem trang cá nhân →',
                              style: tt.badgePrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _openBooking(barberId: b.id),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text('Chọn thợ', style: tt.bodySmallOnPrimary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(BuildContext context, ScrollController ctrl) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

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
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.userName,
                      style: tt.bodyStrong,
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        r.rating,
                        (_) => Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: appColors.starRating,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.comment,
                  style: tt.bodyRegular,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
