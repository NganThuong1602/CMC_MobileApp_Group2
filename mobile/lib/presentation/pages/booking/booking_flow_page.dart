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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final user = context.watch<AuthCubit>().state.user;

    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) async {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: cs.error,
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
                backgroundColor: paid ? cs.primary : appColors.warning,
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
              SnackBar(
                backgroundColor: cs.primary,
                content: const Text(
                  'Đặt lịch thành công! Hẹn gặp bạn tại quán.',
                ),
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
              style: tt.dialogTitle,
            ),
          ),
          body: state.isLoading && state.shop == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle(context, '1. Chọn Barber phục vụ'),
                    const SizedBox(height: 10),
                    _buildBarberSelector(context, state),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      context,
                      '2. Chọn Dịch vụ (Tự động cộng thời lượng)',
                    ),
                    const SizedBox(height: 10),
                    _buildServiceMultiSelector(context, state),
                    const SizedBox(height: 14),
                    _buildDurationSummaryBanner(context, state),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      context,
                      '3. Chọn Ngày & Khung giờ còn trống',
                    ),
                    const SizedBox(height: 10),
                    _buildHorizontalDateStrip(context, state),
                    const SizedBox(height: 14),
                    _buildSlotLegend(context),
                    const SizedBox(height: 12),
                    _buildTwoRowContinuousTimeline(context, state),
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, '4. Phương thức thanh toán'),
                    const SizedBox(height: 10),
                    _buildPaymentSelector(context, state),
                    const SizedBox(height: 90),
                  ],
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
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
                          style: tt.bodySmallMuted,
                        ),
                        Text(
                          AppFormatters.formatVnd(state.totalPrice),
                          style: tt.priceLargePrimary,
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.appTextStyles.sectionTitle,
    );
  }

  Widget _buildBarberSelector(BuildContext context, BookingState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    if (state.barbers.isEmpty) {
      return Text(
        'Quán hiện chưa có Barber nào.',
        style: tt.bodyMuted,
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
                color: selected ? cs.primaryContainer : cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primary,
                    backgroundImage: barber.avatarUrl != null
                        ? NetworkImage(barber.avatarUrl!)
                        : null,
                    child: barber.avatarUrl == null
                        ? Icon(Icons.person, color: cs.onPrimary, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    barber.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmallStrong,
                  ),
                  Text(
                    '⭐ ${barber.rating.toStringAsFixed(1)}',
                    style: tt.captionMuted,
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Column(
      children: state.services.map((service) {
        final checked =
            state.selectedServices.any((s) => s.id == service.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: checked ? cs.primary : cs.outline,
            ),
          ),
          child: CheckboxListTile(
            value: checked,
            activeColor: cs.primary,
            onChanged: (_) =>
                context.read<BookingBloc>().add(BookingServiceToggled(service)),
            title: Text(
              service.name,
              style: tt.bodyStrong,
            ),
            subtitle: Text(
              '${service.durationMinutes} phút • ${AppFormatters.formatVnd(service.price)}',
              style: tt.bodySmallMuted,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSummaryBanner(BuildContext context, BookingState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: cs.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã chọn ${state.selectedServices.length} dịch vụ • Tổng thời lượng: ${state.totalDurationMinutes} phút',
              style: tt.bodySmallPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDateStrip(BuildContext context, BookingState state) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
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
                color: selected ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'H.Nay' : AppFormatters.weekdayShortVi(d),
                    style: selected ? tt.captionOnPrimary : tt.captionMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.day}/${d.month}',
                    style: selected ? tt.bodySmallOnPrimary : tt.bodyStrong,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotLegend(BuildContext context) {
    final cs = context.colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendDot(context, cs.surface, 'Còn trống', border: cs.primary),
        _legendDot(context, cs.primary, 'Đang chọn'),
        _legendDot(context, cs.surfaceContainerHighest, 'Đã có người đặt'),
        _legendDot(context, cs.errorContainer, 'Khóa do tràn giờ'),
      ],
    );
  }

  Widget _legendDot(
    BuildContext context,
    Color bg,
    String text, {
    Color? border,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border ?? AppTheme.transparent),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: context.appTextStyles.captionMuted,
        ),
      ],
    );
  }

  Widget _buildTwoRowContinuousTimeline(
    BuildContext context,
    BookingState state,
  ) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final schedule = state.daySchedule;

    if (schedule == null) {
      return const SizedBox.shrink();
    }
    final openStr = state.shop?.openTime ?? '08:30';
    final closeStr = state.shop?.closeTime ?? '20:30';

    return Container(
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
            'Ca sáng ($openStr - 11:30)',
            style: tt.bodyStrong,
          ),
          const SizedBox(height: 8),
          _buildContinuousShiftRow(context, state, schedule.morningSlots),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Nghỉ trưa cố định: 11:30 - 14:00',
                    style: tt.captionMuted,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          Text(
            'Ca chiều (14:00 - $closeStr)',
            style: tt.bodyStrong,
          ),
          const SizedBox(height: 8),
          _buildContinuousShiftRow(context, state, schedule.afternoonSlots),
          if (state.selectedSlot != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Khung giờ phục vụ dự kiến: ${state.selectedSlot!.allocatedRangeLabel} (${state.totalDurationMinutes} phút)',
                style: tt.bodySmallPrimary,
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

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

          Color bgColor = cs.surface;
          Color borderColor = cs.primary.withValues(alpha: 0.55);
          TextStyle timeStyle = tt.bodySmallStrong;
          TextStyle statusStyle = tt.badgePrimary;
          Color iconColor = cs.primary;

          if (isSelected) {
            bgColor = cs.primary;
            borderColor = cs.primary;
            timeStyle = tt.bodySmallOnPrimary;
            statusStyle = tt.captionOnPrimary;
            iconColor = cs.onPrimary;
          } else if (slot.isBooked) {
            bgColor = cs.surfaceContainerHighest;
            borderColor = cs.outline;
            timeStyle = tt.bodySmallMuted;
            statusStyle = tt.captionMuted;
            iconColor = cs.onSurfaceVariant;
          } else if (slot.hasDurationConflict) {
            bgColor = cs.errorContainer;
            borderColor = cs.error.withValues(alpha: 0.35);
            timeStyle = tt.bodySmallDanger;
            statusStyle = tt.badgeDanger;
            iconColor = cs.error;
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
                    style: timeStyle,
                  ),
                  const SizedBox(height: 2),
                  if (slot.isBooked)
                    Text(
                      'Đã đặt',
                      style: statusStyle,
                    )
                  else if (slot.hasDurationConflict)
                    Icon(Icons.lock_outline_rounded, size: 12, color: iconColor)
                  else
                    Text(
                      'Trống',
                      style: statusStyle,
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
    final cs = context.colorScheme;
    final tt = context.appTextStyles;

    return Column(
      children: PaymentMethod.values.map((m) {
        final selected = state.paymentMethod == m;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
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
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            title: Text(
              m.label,
              style: tt.bodyStrong,
            ),
            subtitle: Text(
              m == PaymentMethod.qrCode
                  ? 'Tạo mã VietQR động, SePay tự động xác nhận Hoàn thành qua Socket.IO'
                  : 'Thanh toán trực tiếp cho Barber sau khi cắt xong',
              style: tt.bodySmallMuted,
            ),
          ),
        );
      }).toList(),
    );
  }
}
