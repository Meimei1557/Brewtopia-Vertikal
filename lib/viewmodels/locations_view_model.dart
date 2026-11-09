import 'package:flutter/foundation.dart';
import '../core/location_service.dart';
import '../data/models/game_snapshot.dart';
import '../data/repositories/game_repository.dart';

/// Kelola banyak "kafe favorit" (geolocation): simpan, hapus, dan check-in harian di tiap titik.
class LocationsViewModel extends ChangeNotifier {
  LocationsViewModel(this._repo, this._location);

  final GameRepository _repo;
  final LocationService _location;

  static const double radiusMeters = 200;
  static const int maxSpots = 10;

  GameSnapshot snapshot = GameSnapshot();
  bool loading = true;
  bool locating = false;
  String? city;
  String? message;
  LocationStatus? status;
  double? _lat;
  double? _lng;

  bool get hasFix => _lat != null;
  List<CafeSpot> get spots => snapshot.spots;
  bool get bonusActive => snapshot.bonusActive;

  static String today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> init() async {
    snapshot = await _repo.load();
    city = _repo.cachedCity;
    loading = false;
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    locating = true;
    message = null;
    notifyListeners();
    final r = await _location.currentFix();
    status = r.status;
    if (r.fix != null) {
      _lat = r.fix!.lat;
      _lng = r.fix!.lng;
      if (r.fix!.city != null) {
        city = r.fix!.city;
        await _repo.rememberCity(city!);
      }
    } else {
      message = switch (r.status) {
        LocationStatus.serviceOff => 'GPS mati. Nyalakan lokasi di pengaturan.',
        LocationStatus.denied => 'Izin lokasi ditolak.',
        LocationStatus.deniedForever =>
          'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        _ => 'Gagal mendapatkan lokasi (${r.detail ?? 'tidak diketahui'}). Nyalakan GPS dan coba lagi.',
      };
    }
    locating = false;
    notifyListeners();
  }

  Future<void> openSettings() => _location.openAppSettings();

  double? distanceTo(CafeSpot s) =>
      _lat == null ? null : _location.distanceMeters(_lat!, _lng!, s.lat, s.lng);

  bool checkedToday(CafeSpot s) => s.lastCheckInDay == today();

  bool canCheckIn(CafeSpot s) {
    final d = distanceTo(s);
    return d != null && d <= radiusMeters && !checkedToday(s);
  }

  Future<void> addSpotHere(String name) async {
    if (snapshot.spots.length >= maxSpots) {
      message = 'Maksimal $maxSpots lokasi favorit.';
      notifyListeners();
      return;
    }
    if (_lat == null) {
      await refreshLocation();
      if (_lat == null) return;
    }
    final clean = name.trim().isEmpty ? 'Kafe ${snapshot.spots.length + 1}' : name.trim();
    snapshot.spots.add(CafeSpot(name: clean, lat: _lat!, lng: _lng!));
    await _repo.save(snapshot);
    await _repo.setCloudDirty(true);
    message = '"$clean" tersimpan. Datang lagi ke sini untuk check-in!';
    notifyListeners();
  }

  Future<void> removeSpot(int i) async {
    if (i < 0 || i >= snapshot.spots.length) return;
    snapshot.spots.removeAt(i);
    await _repo.save(snapshot);
    notifyListeners();
  }

  /// Check-in harian: koin + bonus pendapatan x1.5 selama 30 menit.
  Future<void> checkIn(int i) async {
    if (i < 0 || i >= snapshot.spots.length) return;
    await refreshLocation();
    if (!hasFix) return;
    final s = snapshot.spots[i];
    if (checkedToday(s)) {
      message = 'Sudah check-in di "${s.name}" hari ini.';
    } else if (!canCheckIn(s)) {
      message = 'Kamu ${distanceTo(s)?.round() ?? '?'} m dari "${s.name}". Dekati sampai ${radiusMeters.round()} m.';
    } else {
      final reward = 150 + snapshot.level * 30;
      snapshot.money += reward;
      snapshot.totalEarned += reward;
      s.lastCheckInDay = today();
      snapshot.bonusUntilMs =
          DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch;
      await _repo.save(snapshot);
      await _repo.setCloudDirty(true);
      message = 'Check-in di "${s.name}" berhasil! +$reward koin & bonus x1.5 selama 30 menit.';
    }
    notifyListeners();
  }
}
