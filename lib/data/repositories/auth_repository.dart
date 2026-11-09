import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

abstract class AuthRepository {
  /// false bila Firebase belum dikonfigurasi (mode offline).
  bool get cloudAvailable;
  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password, String name);
  Future<void> signInAsGuest();
  Future<void> signOut();
  Future<void> deleteAccount();
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? _map(User? u) {
    if (u == null) return null;
    final name = (u.displayName?.trim().isNotEmpty ?? false)
        ? u.displayName!
        : (u.isAnonymous ? 'Tamu ${u.uid.substring(0, 4)}' : (u.email?.split('@').first ?? 'Barista'));
    return AppUser(uid: u.uid, displayName: name, email: u.email, isGuest: u.isAnonymous);
  }

  @override
  bool get cloudAvailable => true;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    } catch (_) {
      throw AuthException('Terjadi kesalahan. Periksa koneksi internetmu.');
    }
  }

  String _message(String code) => switch (code) {
        'invalid-email' => 'Format email tidak valid.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email atau kata sandi salah.',
        'email-already-in-use' => 'Email sudah terdaftar. Silakan masuk.',
        'weak-password' => 'Kata sandi minimal 6 karakter.',
        'network-request-failed' => 'Tidak ada koneksi internet.',
        'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
        'requires-recent-login' => 'Masuk ulang dulu, lalu ulangi permintaan ini.',
        'operation-not-allowed' =>
          'Metode login belum diaktifkan di Firebase Console.',
        _ => 'Gagal ($code).',
      };

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
      () => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> registerWithEmail(String email, String password, String name) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user?.updateDisplayName(name.trim());
        await cred.user?.reload();
      });

  @override
  Future<void> signInAsGuest() => _guard(() => _auth.signInAnonymously());

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() => _guard(() async => _auth.currentUser?.delete());
}

/// Dipakai bila Firebase belum dikonfigurasi: game tetap bisa dimainkan offline.
class OfflineAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  bool get cloudAvailable => false;
  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  void _set(AppUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signInAsGuest() async =>
      _set(const AppUser(uid: 'local', displayName: 'Barista', isGuest: true));
  @override
  Future<void> signInWithEmail(String email, String password) => signInAsGuest();
  @override
  Future<void> registerWithEmail(String email, String password, String name) =>
      signInAsGuest();
  @override
  Future<void> signOut() async => _set(null);
  @override
  Future<void> deleteAccount() async => _set(null);
}
