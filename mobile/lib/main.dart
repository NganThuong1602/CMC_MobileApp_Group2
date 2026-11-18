import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/network/api_client.dart';
import 'core/services/fcm_service.dart';
import 'data/datasources/remote/remote_api_datasource.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  await sl<FcmService>().initialize(
    onTokenSync: (token, platform) async {
      final accessToken = sl<ApiClient>().accessToken;
      if (accessToken == null || accessToken.isEmpty) return;
      await sl<RemoteApiDataSource>().registerFcmToken(
        token,
        platform: platform,
      );
    },
  );
  runApp(const BarberSmartApp());
}
