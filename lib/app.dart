import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/routes/app_router.dart';

class BarberBookingApp extends StatelessWidget {
  const BarberBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barber Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

