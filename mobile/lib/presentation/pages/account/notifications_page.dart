import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/repositories/barber_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotificationEntity> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<SocialRepository>().getUserNotifications(user.id);
    if (mounted) {
      setState(() {
        _items = res.data ?? [];
        _loading = false;
      });
    }
  }

  bool _isBarberInvitation(AppNotificationEntity n) {
    final titleLower = n.title.toLowerCase();
    return n.type == NotificationType.barberInvitation ||
        titleLower.contains('lời mời làm barber') ||
        titleLower.contains('mời bạn gia nhập đội ngũ barber');
  }

  bool _isInviteResponded(AppNotificationEntity n) {
    return n.payload?['responded'] == true;
  }

  Future<bool> _respondInvite(
    AppNotificationEntity notif,
    bool accept,
  ) async {
    final cs = context.colorScheme;
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return false;
    final res = await sl<BarberRepository>().respondBarberInvitation(
      notificationId: notif.id,
      userId: user.id,
      accept: accept,
    );
    if (!mounted) return false;
    bool succeeded = false;
    await res.fold(
      onFailure: (f) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message), backgroundColor: cs.error),
        );
      },
      onSuccess: (_) async {
        succeeded = true;
        await context.read<AuthCubit>().refreshCurrentUser();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.primary,
              content: Text(
                accept
                    ? 'Chúc mừng! Bạn đã trở thành Barber của quán.'
                    : 'Đã từ chối lời mời làm Barber.',
              ),
            ),
          );
        }
      },
    );
    return succeeded;
  }

  Future<void> _openBarberInviteDetailPage(AppNotificationEntity notif) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BarberInvitationDetailPage(
          notification: notif,
          isInitiallyResponded: _isInviteResponded(notif),
          onRespond: (accept) => _respondInvite(notif, accept),
        ),
      ),
    );
    if (mounted) {
      _load();
    }
  }

  Future<void> _showRejectedShopDialog(AppNotificationEntity notif) async {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final reasonFromMeta =
        (notif.payload?['rejectionReason'] ?? '').toString().trim();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: cs.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chi tiết từ chối mở quán',
                style: tt.dialogTitle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif.title, style: tt.cardTitle),
            const SizedBox(height: 4),
            Text(
              'Thời gian: ${AppFormatters.formatRelativeTime(notif.createdAt)}',
              style: tt.captionMuted,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.error.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nội dung & Lý do từ chối từ Admin:',
                    style: tt.bodySmallDanger,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reasonFromMeta.isNotEmpty
                        ? 'Lý do: "$reasonFromMeta"\n\n${notif.body}'
                        : notif.body,
                    style: tt.bodyRegular,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Đóng'),
          ),
        ],
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
        title: const Text('Thông báo'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Bạn chưa có thông báo nào.',
                    style: tt.bodyMuted,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final n = _items[i];
                    final isInvite = _isBarberInvitation(n);
                    final isResponded = _isInviteResponded(n);

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final currentUser =
                            context.read<AuthCubit>().state.user;
                        await sl<SocialRepository>().markNotificationRead(n.id);
                        if (!context.mounted) return;

                        // Nếu là thông báo mời làm Barber -> mở sang trang chi tiết lời mời để Xác nhận / Từ chối
                        if (isInvite) {
                          await _openBarberInviteDetailPage(n);
                          return;
                        }

                        final roomId =
                            (n.targetRoomId ?? n.payload?['roomId'] ?? '')
                                .toString()
                                .trim();
                        final titleLower = n.title.toLowerCase();
                        final isChatNotif =
                            n.type == NotificationType.chatMessage ||
                                titleLower.contains('tin nhắn') ||
                                titleLower.contains('phản hồi từ quán');

                        if (isChatNotif) {
                          if (currentUser?.role == UserRole.manager) {
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            final encodedHint = Uri.encodeComponent(n.title);
                            context.go(
                              '/?tab=2&openConsult=1&roomId=$roomId&customerHint=$encodedHint&ts=$ts',
                            );
                            return;
                          } else if (roomId.isNotEmpty) {
                            await context.push('/chat/$roomId');
                            if (mounted) _load();
                            return;
                          }
                        } else if (n.type == NotificationType.shopApproval) {
                          if (currentUser?.role == UserRole.admin) {
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            context.go('/?tab=2&ts=$ts');
                            return;
                          }
                          final isRejectedNotif =
                              n.payload?['approved'] == false ||
                                  titleLower.contains('từ chối');
                          if (isRejectedNotif) {
                            if (mounted) _load();
                            await _showRejectedShopDialog(n);
                            return;
                          }

                          await context.read<AuthCubit>().refreshCurrentUser();
                          if (!context.mounted) return;
                          final refreshedUser =
                              context.read<AuthCubit>().state.user;
                          final isApprovedNotif =
                              n.payload?['approved'] == true ||
                                  titleLower.contains('phê duyệt');
                          if (refreshedUser?.role == UserRole.manager &&
                              isApprovedNotif) {
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            context.go('/?tab=2&ts=$ts');
                            return;
                          }
                        }

                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? cs.surface
                              : cs.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: appColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: tt.cardTitle,
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatRelativeTime(n.createdAt),
                                  style: tt.captionMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.body,
                              style: tt.bodyRegular,
                            ),
                            if (isInvite && !isResponded) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _respondInvite(n, true),
                                    child: const Text('Đồng ý làm Barber'),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: () => _respondInvite(n, false),
                                    child: const Text('Từ chối'),
                                  ),
                                ],
                              ),
                            ] else if (isInvite && isResponded) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Đã phản hồi lời mời',
                                style: tt.bodySmallPrimary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Trang chi tiết Lời mời làm Barber khi người dùng bấm vào thông báo lời mời:
/// Cho phép xem đầy đủ thông tin lời mời và bấm "Xác nhận làm Barber" hoặc "Từ chối".
class _BarberInvitationDetailPage extends StatefulWidget {
  final AppNotificationEntity notification;
  final bool isInitiallyResponded;
  final Future<bool> Function(bool accept) onRespond;

  const _BarberInvitationDetailPage({
    required this.notification,
    required this.isInitiallyResponded,
    required this.onRespond,
  });

  @override
  State<_BarberInvitationDetailPage> createState() =>
      _BarberInvitationDetailPageState();
}

class _BarberInvitationDetailPageState
    extends State<_BarberInvitationDetailPage> {
  bool _submitting = false;
  late bool _responded;

  @override
  void initState() {
    super.initState();
    _responded = widget.isInitiallyResponded;
  }

  Future<void> _handleDecision(bool accept) async {
    setState(() => _submitting = true);
    final ok = await widget.onRespond(accept);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _responded = true;
    });
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final n = widget.notification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết lời mời làm Barber'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: appColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.content_cut_rounded,
                        color: cs.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: tt.sectionTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatRelativeTime(n.createdAt),
                            style: tt.captionMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Nội dung lời mời:',
                  style: tt.cardTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  n.body,
                  style: tt.bodyRegular,
                ),
                const SizedBox(height: 24),
                if (_responded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Bạn đã phản hồi lời mời này.',
                      style: tt.bodyStrong,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _handleDecision(false),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Từ chối'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _handleDecision(true),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              _submitting ? 'Đang xử lý...' : 'Xác nhận',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
