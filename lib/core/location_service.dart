import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatus { ok, serviceOff, denied, deniedForever, error }

class LocationFix {
  const LocationFix(this.lat, this.lng, this.city);
  final double lat;
  final double lng;
  final String? city;
}

class LocationResult {
  const LocationResult(this.status, [this.fix, this.detail]);
  final LocationStatus status;
  final LocationFix? fix;
  final String? detail;
}

/// Pembungkus geolocator + geocoding (lokasi hanya saat app dibuka).
class LocationService {
  Future<LocationStatus> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationStatus.serviceOff;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return LocationStatus.denied;
      if (p == LocationPermission.deniedForever) return LocationStatus.deniedForever;
      return LocationStatus.ok;
    } catch (e) {
      return LocationStatus.error;
    }
  }

  /// Ambil posisi: coba posisi terakhir (cepat), lalu posisi segar (akurasi sedang, batas 25 dtk).
  /// Bila posisi segar gagal tapi ada posisi terakhir, pakai itu supaya tidak error di dalam ruangan.
  Future<LocationResult> currentFix() async {
    final status = await ensurePermission();
    if (status != LocationStatus.ok) return LocationResult(status);
    Position? pos;
    String? err;
    try {
      pos = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 25),
        ),
      );
    } catch (e) {
      err = e.toString();
    }
    if (pos == null) {
      return LocationResult(LocationStatus.error, null, err ?? 'Posisi tidak tersedia');
    }
    final city = await _cityFor(pos.latitude, pos.longitude);
    return LocationResult(LocationStatus.ok, LocationFix(pos.latitude, pos.longitude, city));
  }

  Future<String?> _cityFor(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 8));
      if (list.isEmpty) return null;
      final p = list.first;
      final c = (p.subAdministrativeArea?.isNotEmpty ?? false) ? p.subAdministrativeArea : p.locality;
      return (c == null || c.isEmpty) ? null : c;
    } catch (_) {
      return null;
    }
  }

  double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
