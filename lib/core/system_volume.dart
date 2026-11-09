import 'package:flutter/services.dart';

/// Volume media HP (0..1) yang sinkron dua arah dengan tombol volume & slider di app.
class SystemVolume {
  static const _method = MethodChannel('brewtopia/volume');
  static const _events = EventChannel('brewtopia/volume_events');

  Future<double> get() async {
    try {
      final v = await _method.invokeMethod<double>('get');
      return (v ?? 0.5).clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return 0.5;
    }
  }

  Future<double> set(double value) async {
    try {
      final v = await _method.invokeMethod<double>('set', {'value': value.clamp(0.0, 1.0)});
      return (v ?? value).clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return value;
    }
  }

  Stream<double> get changes => _events
      .receiveBroadcastStream()
      .map((e) => (e as num).toDouble().clamp(0.0, 1.0).toDouble())
      .handleError((_) {});
}
