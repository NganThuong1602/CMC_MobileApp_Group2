import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/time_slot_entity.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/booking/booking_bloc.dart';
import '../../widgets/sepay_qr_dialog.dart';

/// Luồng Đặt lịch Core Logic Complex:
/// 1. Chọn Barber -> Chọn nhiều Dịch vụ -> Tự cộng dồn Tổng thời gian & Tổng giá.
/// 2. Thanh ngang chọn ngày + 2 hàng ngang liên tục:
///    - Ca sáng (openTime - 11:30)
///    - Ca chiều (14:00 - closeTime)
/// 3. Chặn tràn giờ (Disable ngay nếu `start + totalDuration` lấn qua 11:30 hoặc closeTime)
///    & chuyển xám các mốc giờ đã có khách đặt.
/// 4. Hỗ trợ Thanh toán tại quán hoặc QR Code động (SePay Webhook tự động chuyển COMPLETED).
class BookingFlowPage extends StatelessWidget {
  final String shopId;
  final String? preselectedBarberId;

  const BookingFlowPage({
    super.key,
    required this.shopId,
    this.preselectedBarberId,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    return BlocProvider<BookingBloc>(
      create: (_) => sl<BookingBloc>()
        ..add(
          BookingInitialized(
            shopId: shopId,
            preselectedBarberId: preselectedBarberId,
            currentUserId: user?.id,
          ),
        ),
      child: const _BookingFlowView(),
    );
  }
}

class _BookingFlowView extends StatelessWidget {
  const _BookingFlowView();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) async {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }

        if (state.createdBundle != null) {
          final bundle = state.createdBundle!;
          if (bundle.paymentQr != null) {
            final paid = await SepayQrDialog.show(
              context,
              title: 'Quét QR SePay thanh toán lịch cắt',
              transaction: bundle.paymentQr!,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor:
                    paid ? AppTheme.primaryGreen : Colors.orange.shade800,
                content: Text(
                  paid
                      ? 'SePay đã xác nhận! Lịch cắt đã tự động chuyển sang Hoàn thành.'
                      : 'Lịch đã ghi nhận ở trạng thái chờ thanh toán QR.',
                ),
              ),
            );
            context.go('/my-bookings');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.primaryGreen,
                content: Text('Đặt lịch thành công! Hẹn gặp bạn tại quán.'),
              ),
            );
            context.go('/my-bookings');
          }
        }
      },
      builder: (context, state) {
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
              state.shop?.name ?? 'Đặt lịch cắt tóc',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          body: state.isLoading && state.shop == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('1. Chọn Barber phục vụ'),
                    const SizedBox(height: 10),
                    _buildBarberSelector(context, state),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      '2. Chọn Dịch vụ (Tự động cộng thời lượng)',
                    ),
                    const SizedBox(height: 10),
                    _buildServiceMultiSelector(context, state),
                    const SizedBox(height: 14),
                    _buildDurationSummaryBanner(state),
                    const SizedBox(height: 20),
                    _buildSectionTitle('3. Chọn Ngày & Khung giờ còn trống'),
                    const SizedBox(height: 10),
                    _buildHorizontalDateStrip(context, state),
                    const SizedBox(height: 14),
                    _buildSlotLegend(),
                    const SizedBox(height: 12),
                    _buildTwoRowContinuousTimeline(context, state),
                    const SizedBox(height: 20),
                    _buildSectionTitle('4. Phương thức thanh toán'),
                    const SizedBox(height: 10),
                    _buildPaymentSelector(context, state),
                    const SizedBox(height: 90),
                  ],
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng cộng (${state.totalDurationMinutes} phút)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          AppFormatters.formatVnd(state.totalPrice),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (state.isLoading ||
                            user == null ||
                            state.selectedSlot == null ||
                            state.selectedServices.isEmpty)
                        ? null
                        : () {
                            context
                                .read<BookingBloc>()
                                .add(BookingSubmitted(user.id));
                          },
                    child: Text(
                      state.paymentMethod == PaymentMethod.qrCode
                          ? 'Tạo QR & Đặt lịch'
                          : 'Xác nhận đặt lịch',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildBarberSelector(BuildContext context, BookingState state) {
    if (state.barbers.isEmpty) {
      return const Text(
        'Quán hiện chưa có Barber nào.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.barbers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final barber = state.barbers[i];
          final selected = state.selectedBarber?.id == barber.id;
          return GestureDetector(
            onTap: () =>
                context.read<BookingBloc>().add(BookingBarberSelected(barber)),
            child: Container(
              width: 145,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryGreenLight
                    : AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryGreen
                      : const Color(0xFFE5EAF0),
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryGreen,
                    backgroundImage: barber.avatarUrl != null
                        ? NetworkImage(barber.avatarUrl!)
                        : null,
                    child: barber.avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    barber.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '⭐ ${barber.rating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceMultiSelector(BuildContext context, BookingState state) {
    return Column(
      children: state.services.map((service) {
        final checked =
            state.selectedServices.any((s) => s.id == service.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  checked ? AppTheme.primaryGreen : const Color(0xFFE8ECF2),
            ),
          ),
          child: CheckboxListTile(
            value: checked,
            activeColor: AppTheme.primaryGreen,
            onChanged: (_) =>
                context.read<BookingBloc>().add(BookingServiceToggled(service)),
            title: Text(
              service.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${service.durationMinutes} phút • ${AppFormatters.formatVnd(service.price)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSummaryBanner(BookingState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreenLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã chọn ${state.selectedServices.length} dịch vụ • Tổng thời lượng: ${state.totalDurationMinutes} phút',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDateStrip(BuildContext context, BookingState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));

    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final d = dates[i];
          final selected = d.year == state.selectedDate.year &&
              d.month == state.selectedDate.month &&
              d.day == state.selectedDate.day;
          return GestureDetector(
            onTap: () =>
                context.read<BookingBloc>().add(BookingDateChanged(d)),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryGreen : AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryGreen
                      : const Color(0xFFE5EAF0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'H.Nay' : AppFormatters.weekdayShortVi(d),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.day}/${d.month}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendDot(Colors.white, 'Còn trống', border: AppTheme.primaryGreen),
        _legendDot(AppTheme.primaryGreen, 'Đang chọn'),
        _legendDot(const Color(0xFFDADFE6), 'Đã có người đặt'),
        _legendDot(const Color(0xFFF3E5E5), 'Khóa do tràn giờ'),
      ],
    );
  }

  Widget _legendDot(Color bg, String text, {Color? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border ?? Colors.transparent),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTwoRowContinuousTimeline(
    BuildContext context,
    BookingState state,
  ) {
    final schedule = state.daySchedule;
    if (schedule == null) {
      return const SizedBox.shrink();
    }
    final openStr = state.shop?.openTime ?? '08:30';
    final closeStr = state.shop?.closeTime ?? '20:30';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ca sáng ($openStr - 11:30)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildContinuousShiftRow(context, state, schedule.morningSlots),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Nghỉ trưa cố định: 11:30 - 14:00',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          Text(
            'Ca chiều (14:00 - $closeStr)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildContinuousShiftRow(context, state, schedule.afternoonSlots),
          if (state.selectedSlot != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Khung giờ phục vụ dự kiến: ${state.selectedSlot!.allocatedRangeLabel} (${state.totalDurationMinutes} phút)',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinuousShiftRow(
    BuildContext context,
    BookingState state,
    List<TimeSlotEntity> slots,
  ) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final slot = slots[i];
          final isSelected =
              state.selectedSlot?.startMinutes == slot.startMinutes;

          Color bgColor = Colors.white;
          Color textColor = AppTheme.textPrimary;
          Color borderColor = AppTheme.primaryGreen.withValues(alpha: 0.55);

          if (isSelected) {
            bgColor = AppTheme.primaryGreen;
            textColor = Colors.white;
            borderColor = AppTheme.primaryGreen;
          } else if (slot.isBooked) {
            // Đã có người đặt -> màu xám
            bgColor = const Color(0xFFE0E4EA);
            textColor = const Color(0xFF8C96A4);
            borderColor = const Color(0xFFD0D6DF);
          } else if (slot.hasDurationConflict) {
            // Bị tràn qua 11:30 / giờ đóng cửa hoặc cấn lịch sau -> Disable khóa
            bgColor = const Color(0xFFF9ECEC);
            textColor = const Color(0xFFB57B7B);
            borderColor = const Color(0xFFEBD2D2);
          }

          return GestureDetector(
            onTap: () {
              if (!slot.isSelectable) {
                if (slot.unavailableReason != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(slot.unavailableReason!),
                    ),
                  );
                }
                return;
              }
              context.read<BookingBloc>().add(BookingSlotSelected(slot));
            },
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (slot.isBooked)
                    Text(
                      'Đã đặt',
                      style: TextStyle(fontSize: 9.5, color: textColor),
                    )
                  else if (slot.hasDurationConflict)
                    Icon(Icons.lock_outline_rounded, size: 12, color: textColor)
                  else
                    Text(
                      'Trống',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected
                            ? Colors.white70
                            : AppTheme.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentSelector(BuildContext context, BookingState state) {
    return Column(
      children: PaymentMethod.values.map((m) {
        final selected = state.paymentMethod == m;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? AppTheme.primaryGreen : const Color(0xFFE5EAF0),
            ),
          ),
          child: ListTile(
            onTap: () => context
                .read<BookingBloc>()
                .add(BookingPaymentMethodChanged(m)),
            leading: Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color:
                  selected ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
            title: Text(
              m.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              m == PaymentMethod.qrCode
                  ? 'Tạo mã VietQR động, SePay tự động xác nhận Hoàn thành qua Socket.IO'
                  : 'Thanh toán trực tiếp cho Barber sau khi cắt xong',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

