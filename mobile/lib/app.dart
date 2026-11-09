import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
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

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _shopDiscoveryCubit = sl<ShopDiscoveryCubit>();
    _router = AppRouter.createRouter(_authCubit);
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
