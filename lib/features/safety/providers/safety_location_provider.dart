import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

@immutable
class SafetyLocationState {
  const SafetyLocationState({
    this.latitude,
    this.longitude,
    this.addressLine,
    this.updatedAt,
    this.loading = false,
    this.error,
  });

  final double? latitude;
  final double? longitude;
  final String? addressLine;
  final DateTime? updatedAt;
  final bool loading;
  final String? error;
}

class SafetyLocationNotifier extends StateNotifier<SafetyLocationState> {
  SafetyLocationNotifier() : super(const SafetyLocationState());

  /// 切换 Tab 或打开安全面板时调用，保持位置信息新鲜。
  Future<void> refresh() async {
    state = SafetyLocationState(
      latitude: state.latitude,
      longitude: state.longitude,
      addressLine: state.addressLine,
      updatedAt: state.updatedAt,
      loading: true,
      error: null,
    );
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const SafetyLocationState(
          loading: false,
          error: '请先在系统设置中开启定位服务',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = const SafetyLocationState(
          loading: false,
          error: '需要定位权限才能使用安全中心',
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      var line =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

      if (!kIsWeb) {
        try {
          final marks =
              await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (marks.isNotEmpty) {
            final p = marks.first;
            final parts = <String>[
              if ((p.street ?? '').trim().isNotEmpty) p.street!,
              if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!,
              if ((p.locality ?? '').trim().isNotEmpty) p.locality!,
              if ((p.administrativeArea ?? '').trim().isNotEmpty)
                p.administrativeArea!,
            ];
            if (parts.isNotEmpty) line = parts.join(' · ');
          }
        } catch (_) {}
      }

      state = SafetyLocationState(
        latitude: pos.latitude,
        longitude: pos.longitude,
        addressLine: line,
        updatedAt: DateTime.now(),
        loading: false,
      );
    } catch (e) {
      state = SafetyLocationState(
        loading: false,
        error: '定位失败：$e',
      );
    }
  }
}

final safetyLocationProvider =
    StateNotifierProvider<SafetyLocationNotifier, SafetyLocationState>(
  (ref) => SafetyLocationNotifier(),
);
