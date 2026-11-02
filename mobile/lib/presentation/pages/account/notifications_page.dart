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

  Future<void> _respondInvite(
    AppNotificationEntity notif,
    bool accept,
  ) async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    final res = await sl<BarberRepository>().respondBarberInvitation(
      notificationId: notif.id,
      userId: user.id,
      accept: accept,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: AppTheme.dangerRed),
      ),
      onSuccess: (_) async {
        await context.read<AuthCubit>().refreshCurrentUser();
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryGreen,
              content: Text(
                accept
                    ? 'Chúc mừng! Bạn đã trở thành Barber của quán.'
                    : 'Đã từ chối lời mời.',
              ),
            ),
          );
        }
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
        title: const Text('Thông báo'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Bạn chưa có thông báo nào.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final n = _items[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await sl<SocialRepository>().markNotificationRead(n.id);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? AppTheme.surfaceWhite
                              : AppTheme.primaryGreenLight.withValues(
                                  alpha: 0.55,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.softCardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatRelativeTime(n.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.body,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (n.type == NotificationType.barberInvitation &&
                                !n.isRead) ...[
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

