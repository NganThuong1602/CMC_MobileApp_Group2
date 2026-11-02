import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/auth/auth_cubit.dart';
import 'presentation/routes/app_router.dart';

class BarberSmartApp extends StatefulWidget {
  const BarberSmartApp({super.key});

  @override
  State<BarberSmartApp> createState() => _BarberSmartAppState();
}

class _BarberSmartAppState extends State<BarberSmartApp> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _router = AppRouter.createRouter(_authCubit);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: _authCubit,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
