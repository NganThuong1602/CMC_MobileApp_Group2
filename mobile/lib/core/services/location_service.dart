import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class DeviceLocationResult {
  final bool granted;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? errorMessage;

  const DeviceLocationResult({
    required this.granted,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 0,
    this.errorMessage,
  });
}

class GeocodedPlaceResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const GeocodedPlaceResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

/// Service lấy tọa độ GPS thực tế của thiết bị thông qua `geolocator`
/// và tìm kiếm tọa độ địa chỉ thực tế trên bản đồ OpenStreetMap (Nominatim).
class LocationService {
  const LocationService();

  /// Cấu hình lấy vị trí độ chính xác cao, KHÔNG dùng vị trí cache cũ
  /// (trên Web `maximumAge: 0` buộc trình duyệt trả về toạ độ GPS mới nhất).
  LocationSettings _settings({int distanceFilterMeters = 0, Duration? timeLimit}) {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMeters,
        maximumAge: Duration.zero,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilterMeters,
      timeLimit: timeLimit,
    );
  }

  /// Kiểm tra định vị đang bật và đã được cấp quyền (không bật popup xin quyền).
  Future<bool> isLocationAvailable() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<DeviceLocationResult?> requestAndGetCurrentLocation() async {
    try {
      if (!await _ensurePermission()) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _settings(timeLimit: const Duration(seconds: 15)),
      );

      return DeviceLocationResult(
        granted: true,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lắng nghe tọa độ GPS thay đổi theo thời gian thực khi người dùng di chuyển.
  /// Khi người dùng tắt định vị / thu hồi quyền, stream phát ra lỗi để UI ẩn chấm vị trí.
  Stream<Position> watchRawPosition({int distanceFilterMeters = 3}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(distanceFilterMeters: distanceFilterMeters),
    );
  }

  /// Lắng nghe tọa độ GPS thay đổi theo thời gian thực khi người dùng di chuyển.
  Stream<DeviceLocationResult> watchDeviceLocation({
    int distanceFilterMeters = 5,
  }) async* {
    try {
      if (!await _ensurePermission()) return;
    } catch (_) {
      return;
    }
    yield* watchRawPosition(distanceFilterMeters: distanceFilterMeters).map(
      (pos) => DeviceLocationResult(
        granted: true,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
      ),
    );
  }

  /// Tìm tọa độ (vĩ độ, kinh độ) trên bản đồ OpenStreetMap từ chuỗi địa chỉ người dùng nhập.
  /// Tự động bóc tách số nhà/ngõ nếu dữ liệu OSM chỉ lưu tới cấp Đường/Phố/Phường/Quận.
  Future<GeocodedPlaceResult?> geocodeAddress(String rawAddress) async {
    final cleaned = rawAddress.trim();
    if (cleaned.isEmpty) return null;

    final candidates = _buildQueryCandidates(cleaned);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: const {
          'Accept-Language': 'vi,en',
        },
      ),
    );

    for (final q in candidates) {
      try {
        final res = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'format': 'json',
            'q': q,
            'countrycodes': 'vn',
            'limit': 1,
          },
        );
        final list = res.data;
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          if (first is Map) {
            final lat = double.tryParse((first['lat'] ?? '').toString());
            final lon = double.tryParse((first['lon'] ?? '').toString());
            if (lat != null && lon != null) {
              return GeocodedPlaceResult(
                latitude: lat,
                longitude: lon,
                displayName: (first['display_name'] ?? q).toString(),
              );
            }
          }
        }
      } catch (_) {}
    }

    return _fallbackLocalKeywordMatch(cleaned);
  }

  List<String> _buildQueryCandidates(String address) {
    final result = <String>[];
    void addUnique(String s) {
      final v = s.trim();
      if (v.isNotEmpty && !result.contains(v)) {
        result.add(v);
      }
    }

    addUnique(address);
    if (!address.toLowerCase().contains('hà nội') &&
        (address.toLowerCase().contains('hà đông') ||
            address.toLowerCase().contains('vạn phúc') ||
            address.toLowerCase().contains('cầu giấy') ||
            address.toLowerCase().contains('đống đa') ||
            address.toLowerCase().contains('thanh xuân'))) {
      addUnique('$address, Hà Nội');
    }

    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      // Lọc bỏ các cụm chỉ số nhà / ngõ / ngách ở đầu để tìm đúng tên Phố / Phường
      final streetParts = parts.where((p) {
        final low = p.toLowerCase();
        if (RegExp(r'^\d+[a-zA-Z/\-]*$').hasMatch(low)) return false;
        if (low.startsWith('ngõ ') ||
            low.startsWith('ngách ') ||
            low.startsWith('hẻm ') ||
            low.startsWith('số ')) {
          // Nếu cụm có kèm chữ "phố" hoặc "đường" thì giữ từ chữ phố/đường trở đi
          return low.contains('phố ') || low.contains('đường ');
        }
        return true;
      }).map((p) {
        final low = p.toLowerCase();
        final phoIdx = low.indexOf('phố ');
        if (phoIdx > 0) return p.substring(phoIdx).trim();
        final duongIdx = low.indexOf('đường ');
        if (duongIdx > 0) return p.substring(duongIdx).trim();
        return p;
      }).toList();

      if (streetParts.isNotEmpty) {
        final joined = streetParts.join(', ');
        addUnique(joined);
        if (!joined.toLowerCase().contains('hà nội')) {
          addUnique('$joined, Hà Nội');
        }
      }

      for (int i = 1; i < parts.length; i++) {
        final sub = parts.sublist(i).join(', ');
        addUnique(sub);
        if (!sub.toLowerCase().contains('hà nội')) {
          addUnique('$sub, Hà Nội');
        }
      }
    }

    return result;
  }

  GeocodedPlaceResult? _fallbackLocalKeywordMatch(String raw) {
    final low = raw.toLowerCase();
    if (low.contains('phố lụa') || low.contains('làng lụa')) {
      return const GeocodedPlaceResult(
        latitude: 20.9771,
        longitude: 105.7728,
        displayName: 'Phố Lụa, Vạn Phúc, Hà Đông, Hà Nội',
      );
    }
    if (low.contains('tố hữu')) {
      return const GeocodedPlaceResult(
        latitude: 20.9785,
        longitude: 105.7746,
        displayName: 'Tố Hữu, Vạn Phúc, Hà Đông, Hà Nội',
      );
    }
    if (low.contains('nguyễn thanh bình')) {
      return const GeocodedPlaceResult(
        latitude: 20.9776,
        longitude: 105.7695,
        displayName: 'Nguyễn Thanh Bình, Vạn Phúc, Hà Đông, Hà Nội',
      );
    }
    if (low.contains('vạn phúc')) {
      return const GeocodedPlaceResult(
        latitude: 20.9768,
        longitude: 105.7724,
        displayName: 'Vạn Phúc, Hà Đông, Hà Nội',
      );
    }
    if (low.contains('hà đông')) {
      return const GeocodedPlaceResult(
        latitude: 20.9714,
        longitude: 105.7788,
        displayName: 'Quận Hà Đông, Hà Nội',
      );
    }
    return null;
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
