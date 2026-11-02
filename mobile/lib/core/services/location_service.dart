import 'package:geolocator/geolocator.dart';

class DeviceLocationResult {
  final bool granted;
  final double latitude;
  final double longitude;
  final String? errorMessage;

  const DeviceLocationResult({
    required this.granted,
    required this.latitude,
    required this.longitude,
    this.errorMessage,
  });
}

/// Service lấy tọa độ GPS thực tế của thiết bị thông qua `geolocator`
/// (hiển thị popup xin quyền truy cập vị trí thật của hệ điều hành / trình duyệt).
class LocationService {
  const LocationService();

  Future<DeviceLocationResult?> requestAndGetCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return DeviceLocationResult(
        granted: true,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tính khoảng cách thực tế (km) từ vị trí GPS của người dùng tới tọa độ của quán.
  double distanceKm({
    required double userLat,
    required double userLng,
    required double shopLat,
    required double shopLng,
  }) {
    final meters = Geolocator.distanceBetween(
      userLat,
      userLng,
      shopLat,
      shopLng,
    );
    return double.parse((meters / 1000.0).toStringAsFixed(1));
  }
}

