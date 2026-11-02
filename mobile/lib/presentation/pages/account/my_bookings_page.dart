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
              backgroundColor: AppTheme.dangerRed,
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
        SnackBar(content: Text(f.message), backgroundColor: AppTheme.dangerRed),
      ),
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('Đã hủy lịch hẹn thành công!'),
          ),
        );
        _load();
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
        title: const Text('Lịch đã đặt'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(
              Icons.home_outlined,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
            label: const Text(
              'Trang chủ',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : _bookings.isEmpty
              ? const Center(
                  child: Text(
                    'Bạn chưa có lịch cắt tóc nào.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildBookingCard(_bookings[i]),
                ),
    );
  }

  Widget _buildBookingCard(BookingEntity b) {
    final (badgeBg, badgeColor) = switch (b.status) {
      BookingStatus.completed => (
          AppTheme.primaryGreenLight,
          AppTheme.primaryGreen,
        ),
      BookingStatus.cancelled => (
          const Color(0xFFFDECEC),
          AppTheme.dangerRed,
        ),
      BookingStatus.pending => (
          const Color(0xFFFFF4E5),
          const Color(0xFFD97706),
        ),
      BookingStatus.confirmed => (
          const Color(0xFFE8F1FF),
          const Color(0xFF1D4ED8),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.shopName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Barber: ${b.barberName} • Ngày ${AppFormatters.formatDateDdMmYyyy(b.date)} (${b.timeRangeLabel})',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Dịch vụ: ${b.services.map((s) => s.name).join(', ')}',
            style: const TextStyle(fontSize: 13),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Text(
                      '(${b.paymentMethod.label})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (b.canCancel) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.dangerRed),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _cancelBooking(b),
                  child: const Text(
                    'Hủy lịch',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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

