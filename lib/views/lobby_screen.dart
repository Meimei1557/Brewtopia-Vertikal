import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app/di.dart';
import '../app/router.dart';
import '../core/app_exit.dart';
import '../core/audio_service.dart';
import '../core/notification_service.dart';
import '../viewmodels/lobby_view_model.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    getIt<AudioService>().startMusic();
    // Izin notifikasi untuk pendapatan pasif (background task).
    WidgetsBinding.instance.addPostFrameCallback((_) => getIt<NotificationService>().requestPermission());
  }

  Future<void> _play() async {
    await context.push(Routes.game);
    if (mounted) context.read<LobbyViewModel>().refresh();
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Brewtopia?'),
        content: const Text('Progresmu sudah tersimpan otomatis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await exitApp();
  }

  Future<void> _newGame() async {
    final vm = context.read<LobbyViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai game baru?'),
        content: const Text('Progres saat ini (level, koin, dekor, upgrade) akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus & Mulai')),
        ],
      ),
    );
    if (ok == true) {
      await vm.newGame();
      if (mounted) _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LobbyViewModel>();
    final s = vm.snapshot;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: const AssetImage('assets/images/lobby_bg.jpg'), fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.75)],
              stops: const [0, 0.4, 1],
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Column(children: [
                    Row(children: [
                      const CircleAvatar(radius: 15, backgroundColor: Color(0xFF8D6E63), child: Icon(Icons.person, size: 18, color: Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(vm.playerName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      if (vm.syncing)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(vm.cloudAvailable ? Icons.cloud_done : Icons.cloud_off, size: 17, color: vm.cloudAvailable ? Colors.lightGreenAccent : Colors.white54),
                    ]),
                    const Spacer(),
                    const Text('☕', style: TextStyle(fontSize: 46)),
                    Text('BREWTOPIA',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          shadows: const [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3))],
                        )),
                    const Text('Simulasi Kafe', style: TextStyle(fontSize: 13, color: Color(0xFFFFD54F), letterSpacing: 3, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (s.hasProgress)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _stat('Level', '${s.level}'),
                          _div(),
                          _stat('Hari', '${s.day}'),
                          _div(),
                          _stat('Koin', '${s.money}'),
                          _div(),
                          _stat('Reputasi', '⭐${s.reputation.toStringAsFixed(1)}'),
                        ]),
                      ),
                    const Spacer(flex: 2),
                    _PrimaryButton(
                      label: s.hasProgress ? 'LANJUTKAN' : 'MAIN',
                      onTap: vm.loading ? null : _play,
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _SmallButton(Icons.emoji_events, 'Peringkat', () => context.push(Routes.leaderboard))),
                      const SizedBox(width: 8),
                      Expanded(child: _SmallButton(Icons.place, 'Lokasi Kafe', () => context.push(Routes.locations))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _SmallButton(Icons.settings, 'Pengaturan', () => context.push(Routes.settings))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: s.hasProgress
                            ? _SmallButton(Icons.restart_alt, 'Game Baru', _newGame)
                            : _SmallButton(Icons.exit_to_app, 'Keluar', _confirmExit),
                      ),
                    ]),
                    if (s.hasProgress) ...[
                      const SizedBox(height: 8),
                      _SmallButton(Icons.exit_to_app, 'Keluar', _confirmExit),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stat(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(l, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
      );

  Widget _div() => Container(width: 1, height: 22, color: Colors.white24);
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFFE0A24A), Color(0xFFB8702A)]),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(label, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        width: double.infinity,
        child: Material(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: const Color(0xFFFFD54F)),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
