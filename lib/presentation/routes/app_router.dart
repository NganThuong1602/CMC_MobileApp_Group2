import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static const String initialRoute = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initialRoute:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Barber Booking App - Clean Architecture'),
            ),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('404 - Page Not Found'),
            ),
          ),
        );
    }
  }
}

