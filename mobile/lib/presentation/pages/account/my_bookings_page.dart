import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/booking_entity.dart';
import '../../../domain/repositories/booking_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

/// Màn hình Lịch đã đặt của Khách hàng (cho phép Hủy lịch đối với lịch chưa COMPLETED).
class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  List<BookingEntity> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<BookingRepository>().getCustomerBookings(user.id);
    if (mounted) {
      setState(() {
        _bookings = res.data ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _cancelBooking(BookingEntity booking) async {
    final cs = context.colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy lịch?'),
        content: Text(
          'Bạn có chắc muốn hủy lịch hẹn lúc ${booking.timeRangeLabel} tại ${booking.shopName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<BookingRepository>().cancelBooking(
      bookingId: booking.id,
      customerId: user.id,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: cs.error),
      ),
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: const Text('Đã hủy lịch hẹn thành công!'),
          ),
        );
        _load();
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
        title: const Text('Lịch đã đặt'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: Icon(
              Icons.home_outlined,
              size: 18,
              color: cs.primary,
            ),
            label: Text(
              'Trang chủ',
              style: tt.bodySmallPrimary,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _bookings.isEmpty
              ? Center(
                  child: Text(
                    'Bạn chưa có lịch cắt tóc nào.',
                    style: tt.bodyMuted,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildBookingCard(ctx, _bookings[i]),
                ),
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingEntity b) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    final (badgeBg, badgeStyle) = switch (b.status) {
      BookingStatus.completed => (
          cs.primaryContainer,
          tt.badgePrimary,
        ),
      BookingStatus.cancelled => (
          cs.errorContainer,
          tt.badgeDanger,
        ),
      BookingStatus.pending => (
          appColors.warningContainer,
          tt.badgeWarning,
        ),
      BookingStatus.confirmed => (
          appColors.infoContainer,
          tt.badgePrimary.copyWith(color: appColors.info),
        ),
    };

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
            children: [
              Expanded(
                child: Text(
                  b.shopName,
                  style: tt.cardTitleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b.status.label,
                  style: badgeStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Barber: ${b.barberName} • Ngày ${AppFormatters.formatDateDdMmYyyy(b.date)} (${b.timeRangeLabel})',
            style: tt.bodySmallMuted,
          ),
          const SizedBox(height: 4),
          Text(
            'Dịch vụ: ${b.services.map((s) => s.name).join(', ')}',
            style: tt.bodyRegular,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppFormatters.formatVnd(b.totalPrice),
                      style: tt.pricePrimary,
                    ),
                    Text(
                      '(${b.paymentMethod.label})',
                      style: tt.bodySmallMuted,
                    ),
                  ],
                ),
              ),
              if (b.canCancel) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _cancelBooking(b),
                  child: Text(
                    'Hủy lịch',
                    style: tt.bodySmallDanger,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
