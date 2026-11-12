import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../../domain/entities/finance_entities.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/repositories/barber_repository.dart';
import '../../../domain/repositories/booking_repository.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Trung tâm Lịch Barber (Role BARBER) chuẩn Pixel-perfect:
/// - Card quán kèm ảnh bìa lớn có huy hiệu góc trái trên `● ĐANG HOẠT ĐỘNG`.
/// - Tên quán đậm + Giờ mở cửa + SĐT bên dưới.
/// - 3 Card menu:
///   1. `Xem Lịch` (Heatmap theo tháng + Timeline ngày + Nút "Xác nhận đã thanh toán" đổi sang COMPLETED)
///   2. `Tư vấn khách hàng` (Group Chat Socket.IO với khách hàng)
///   3. `Thu nhập` (Lương cứng + 10% hoa hồng từ đơn COMPLETED + Ngày nhận lương dự kiến)
class BarberHubPage extends StatefulWidget {
  const BarberHubPage({super.key});

  @override
  State<BarberHubPage> createState() => _BarberHubPageState();
}

class _BarberHubPageState extends State<BarberHubPage> {
  BarberEntity? _barber;
  ShopEntity? _shop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBarberInfo();
  }

  Future<void> _loadBarberInfo() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final bRes = await sl<BarberRepository>().getBarberByUserId(user.id);
    ShopEntity? shop;
    if (bRes.data != null) {
      final sRes = await sl<ShopRepository>().getShopById(bRes.data!.shopId);
      shop = sRes.data;
    }
    if (mounted) {
      setState(() {
        _barber = bRes.data;
        _shop = shop;
        _loading = false;
      });
    }
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
                  : (_barber == null || _shop == null)
                      ? Center(
                          child: Text(
                            'Bạn chưa thuộc quán cắt tóc nào.',
                            style: tt.bodyMuted,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: appColors.cardShadow,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      AspectRatio(
                                        aspectRatio: 16 / 9.2,
                                        child: Image.network(
                                          _shop!.coverImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: cs.inverseSurface,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: appColors.translucentSurface,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                size: 8,
                                                color: cs.primary,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'ĐANG HOẠT ĐỘNG',
                                                style: tt.badgePrimary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _shop!.name,
                                          style: tt.cardTitleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_filled_rounded,
                                              size: 16,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_shop!.openTime} - ${_shop!.closeTime}',
                                              style: tt.bodyPrimary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_in_talk_rounded,
                                              size: 16,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _shop!.phone,
                                              style: tt.bodySmallPrimary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBarberMenuCard(
                              context: context,
                              icon: Icons.calendar_month_rounded,
                              iconBg: cs.primaryContainer,
                              iconColor: cs.primary,
                              title: 'Xem Lịch',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _BarberScheduleScreen(
                                      barber: _barber!,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildBarberMenuCard(
                              context: context,
                              icon: Icons.account_balance_wallet_rounded,
                              iconBg: appColors.warningContainer,
                              iconColor: appColors.warning,
                              title: 'Thu nhập',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _BarberIncomeScreen(
                                      barber: _barber!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBarberMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
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

class _BarberScheduleScreen extends StatefulWidget {
  final BarberEntity barber;
  const _BarberScheduleScreen({required this.barber});

  @override
  State<_BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<_BarberScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  List<MonthlyBookingHeatDay> _heatmap = [];
  List<BookingEntity> _dayBookings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final hmRes = await sl<BarberRepository>().getMonthlyHeatmap(
      barberId: widget.barber.id,
      year: _selectedDate.year,
      month: _selectedDate.month,
    );
    final dayRes = await sl<BarberRepository>().getBarberDayBookings(
      barberId: widget.barber.id,
      date: _selectedDate,
    );
    if (mounted) {
      setState(() {
        _heatmap = hmRes.data ?? [];
        _dayBookings = dayRes.data ?? [];
      });
    }
  }

  void _showCustomerBookingDetail(BookingEntity booking) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final user = context.read<AuthCubit>().state.user;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khách hàng: ${booking.customerName}',
              style: tt.dialogTitle,
            ),
            const SizedBox(height: 6),
            Text('SĐT: ${booking.customerPhone}'),
            Text('Khung giờ: ${booking.timeRangeLabel}'),
            Text(
              'Dịch vụ: ${booking.services.map((s) => s.name).join(', ')}',
            ),
            const SizedBox(height: 6),
            Text(
              'Tổng tiền: ${AppFormatters.formatVnd(booking.totalPrice)} (${booking.status.label})',
              style: tt.pricePrimary,
            ),
            const SizedBox(height: 16),
            if (booking.status != BookingStatus.completed && user != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await sl<BookingRepository>()
                        .confirmBookingPaidByBarber(
                      bookingId: booking.id,
                      barberUserId: user.id,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    res.fold(
                      onFailure: (f) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(f.message),
                          backgroundColor: cs.error,
                        ),
                      ),
                      onSuccess: (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: cs.primary,
                            content: const Text(
                              'Đã xác nhận thanh toán! Đơn chuyển sang COMPLETED & cộng 10% hoa hồng.',
                            ),
                          ),
                        );
                        _loadData();
                      },
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Xác nhận đã thanh toán'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '✅ Đơn đã Hoàn thành & được ghi nhận doanh thu + 10% hoa hồng.',
                  style: tt.bodySmallPrimary,
                ),
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
        title: Text(
          'Lịch tháng ${_selectedDate.month}/${_selectedDate.year}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heatmap lịch khách đặt trong tháng',
                  style: tt.sectionTitle,
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: _heatmap.length,
                  itemBuilder: (ctx, i) {
                    final h = _heatmap[i];
                    final isSelected = h.date.day == _selectedDate.day;
                    final hasCustomer = h.totalBookings > 0;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = h.date);
                        _loadData();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : hasCustomer
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${h.date.day}',
                              style: isSelected
                                  ? tt.captionOnPrimary
                                  : tt.captionStrong,
                            ),
                            if (hasCustomer)
                              Text(
                                '${h.totalBookings}k',
                                style: isSelected
                                    ? tt.badgeOnPrimary
                                    : tt.badgePrimary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Danh sách khách ngày ${AppFormatters.formatDateDdMmYyyy(_selectedDate)} (${_dayBookings.length})',
            style: tt.sectionTitle,
          ),
          const SizedBox(height: 10),
          if (_dayBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Không có lịch hẹn nào trong ngày này.',
                  style: tt.bodyMuted,
                ),
              ),
            )
          else
            ..._dayBookings.map(
              (b) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: appColors.cardShadow,
                ),
                child: ListTile(
                  onTap: () => _showCustomerBookingDetail(b),
                  leading: CircleAvatar(
                    backgroundColor: b.status == BookingStatus.completed
                        ? cs.primaryContainer
                        : appColors.warningContainer,
                    child: Icon(
                      b.status == BookingStatus.completed
                          ? Icons.check_rounded
                          : Icons.schedule_rounded,
                      color: b.status == BookingStatus.completed
                          ? cs.primary
                          : appColors.warning,
                    ),
                  ),
                  title: Text(
                    '${b.timeRangeLabel} • ${b.customerName}',
                    style: tt.bodyStrong,
                  ),
                  subtitle: Text(
                    '${AppFormatters.formatVnd(b.totalPrice)} • ${b.status.label}',
                    style: tt.bodySmallMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarberIncomeScreen extends StatefulWidget {
  final BarberEntity barber;
  const _BarberIncomeScreen({required this.barber});

  @override
  State<_BarberIncomeScreen> createState() => _BarberIncomeScreenState();
}

class _BarberIncomeScreenState extends State<_BarberIncomeScreen> {
  BarberIncomeSummary? _income;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res =
        await sl<BarberRepository>().getBarberIncomeSummary(widget.barber.id);
    if (mounted) {
      setState(() => _income = res.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Scaffold(
      appBar: AppBar(title: const Text('Thu nhập của tôi')),
      body: _income == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng thu nhập tạm tính trong tháng',
                        style: tt.bodySmallOnPrimary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormatters.formatVnd(_income!.totalIncome),
                        style: tt.heroPriceOnPrimary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _income!.expectedPaydayText,
                        style: tt.bodySmallOnPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _metricTile(
                  context,
                  'Lương cứng cố định',
                  AppFormatters.formatVnd(_income!.baseSalary),
                ),
                _metricTile(
                  context,
                  'Số khách đã Hoàn thành (COMPLETED)',
                  '${_income!.completedCustomerCount} khách',
                ),
                _metricTile(
                  context,
                  'Doanh thu dịch vụ đã hoàn thành',
                  AppFormatters.formatVnd(_income!.completedServiceRevenue),
                ),
                _metricTile(
                  context,
                  'Hoa hồng nhận được (10%)',
                  AppFormatters.formatVnd(_income!.commissionAmount),
                  highlight: true,
                ),
              ],
            ),
    );
  }

  Widget _metricTile(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: appColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMuted,
            ),
          ),
          Text(
            value,
            style: highlight ? tt.pricePrimary : tt.cardTitle,
          ),
        ],
      ),
    );
  }
}
