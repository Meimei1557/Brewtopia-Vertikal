import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';

/// ViewModel autentikasi. Juga dipakai sebagai `refreshListenable` go_router.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repo) {
    _sub = _repo.authStateChanges().listen((u) {
      _user = u;
      _initialized = true;
      notifyListeners();
    }, onError: (_) {
      _initialized = true;
      notifyListeners();
    });
  }

  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _sub;

  AppUser? _user;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get initialized => _initialized;
  bool get isSignedIn => _user != null;
  bool get busy => _busy;
  String? get error => _error;
  bool get cloudAvailable => _repo.cloudAvailable;

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Terjadi kesalahan tak terduga.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signInWithEmail(email, password));

  Future<bool> register(String email, String password, String name) =>
      _run(() => _repo.registerWithEmail(email, password, name));

  Future<bool> signInAsGuest() => _run(_repo.signInAsGuest);

  Future<void> signOut() => _repo.signOut();

  Future<bool> deleteAccount() => _run(_repo.deleteAccount);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
