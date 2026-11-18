import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/auth/auth_cubit.dart';
import 'presentation/blocs/shop_discovery/shop_discovery_cubit.dart';
import 'presentation/routes/app_router.dart';

class BarberSmartApp extends StatefulWidget {
  const BarberSmartApp({super.key});

  @override
  State<BarberSmartApp> createState() => _BarberSmartAppState();
}

class _BarberSmartAppState extends State<BarberSmartApp> {
  late final AuthCubit _authCubit;
  late final ShopDiscoveryCubit _shopDiscoveryCubit;
  late final GoRouter _router;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmTapSub;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _shopDiscoveryCubit = sl<ShopDiscoveryCubit>();
    _router = AppRouter.createRouter(_authCubit);
    _bindFcmListeners();
  }

  void _bindFcmListeners() {
    if (!sl.isRegistered<FcmService>()) return;
    final fcm = sl<FcmService>();
    _fcmForegroundSub = fcm.onForegroundMessage.listen(_showForegroundBanner);
    _fcmTapSub = fcm.onNotificationTap.listen((_) => _openNotificationsPage());
    final initial = fcm.consumePendingInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotificationsPage(),
      );
    }
  }

  void _openNotificationsPage() {
    if (!_authCubit.state.isAuthenticated) return;
    _router.push('/notifications');
  }

  void _showForegroundBanner(RemoteMessage message) {
    final title = message.notification?.title?.trim() ?? '';
    final body = message.notification?.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final messenger = _scaffoldMessengerKey.currentState;
    final ctx = _scaffoldMessengerKey.currentContext;
    if (messenger == null || ctx == null) return;

    final cs = ctx.colorScheme;
    final ts = ctx.appTextStyles;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cs.inverseSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: ts.cardTitle.copyWith(color: cs.onInverseSurface),
                ),
              if (body.isNotEmpty)
                Text(
                  body,
                  style: ts.bodyMuted.copyWith(color: cs.onInverseSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          action: SnackBarAction(
            label: 'Xem',
            textColor: cs.inversePrimary,
            onPressed: _openNotificationsPage,
          ),
        ),
      );
  }

  @override
  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<ShopDiscoveryCubit>.value(value: _shopDiscoveryCubit),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          if (kIsWeb) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: 0),
                viewPadding: mq.viewPadding.copyWith(bottom: 0),
              ),
              child: child,
            );
          }
          return child;
        },
      ),
    );
  }
}
