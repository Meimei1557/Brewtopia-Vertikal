import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio_service.dart';
import '../data/models/customer.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<SettingsViewModel>();
    _vm.startWatching(); // slider volume HP ikut berubah saat tombol volume ditekan
  }

  @override
  void dispose() {
    _vm.stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('PENGATURAN')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _section('Suara'),
        _VolumeRow(
          icon: Icons.phone_android,
          title: 'Volume HP (utama)',
          subtitle: 'Sama dengan tombol volume HP. Geser di sini atau tekan tombol volume, keduanya sinkron.',
          value: vm.systemVolume,
          onChanged: vm.setSystemVolume,
        ),
        _VolumeRow(
          icon: Icons.music_note,
          title: 'Musik latar',
          subtitle: 'Lagu yang mengiringi permainan.',
          value: vm.musicVolume,
          onChanged: vm.setMusicVolume,
        ),
        _VolumeRow(
          icon: Icons.notifications_active,
          title: 'Efek suara',
          subtitle: 'Bunyi pintu, mesin kopi, oven, koin, combo, dan tempat sampah.',
          value: vm.sfxVolume,
          onChanged: vm.setSfxVolume,
          onEnd: vm.previewSfx,
        ),
        _VolumeRow(
          icon: Icons.record_voice_over,
          title: 'Suara dialog',
          subtitle: 'Suara pelanggan & barista berbicara.',
          value: vm.voiceVolume,
          onChanged: vm.setVoiceVolume,
          onEnd: () => vm.speakTest(Gender.female),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
          child: Text('Lagu latar', style: Theme.of(context).textTheme.labelLarge),
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [for (var i = 0; i < AudioService.trackNames.length; i++) ButtonSegment(value: i, label: Text(AudioService.trackNames[i]))],
          selected: {vm.track},
          onSelectionChanged: (s) => vm.setTrack(s.first),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: vm.voiceEnabled,
          onChanged: vm.setVoiceEnabled,
          title: const Text('Aktifkan suara dialog'),
          subtitle: const Text('Butuh Text-to-Speech Bahasa Indonesia di HP. Tanpa itu dialog tetap tampil sebagai teks.'),
        ),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => vm.speakTest(Gender.male), icon: const Icon(Icons.man), label: const Text('Tes suara pria'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => vm.speakTest(Gender.female), icon: const Icon(Icons.woman), label: const Text('Tes suara wanita'))),
        ]),
        _section('Barista'),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: false, label: Text('Barista pria')), ButtonSegment(value: true, label: Text('Barista wanita'))],
          selected: {vm.baristaFemale},
          onSelectionChanged: (s) => vm.setBaristaFemale(s.first),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Berlaku langsung di dalam game (gambar & suara barista).', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
        ),
        _section('Notifikasi & Background'),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: vm.backgroundEnabled,
          onChanged: vm.setBackgroundEnabled,
          title: const Text('Pendapatan pasif & pengingat'),
          subtitle: const Text('Kafe tetap menghasilkan koin saat app ditutup (WorkManager) dan memberi notifikasi.'),
        ),
        _section('Akun'),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person),
          title: Text(vm.userName),
          subtitle: Text(vm.isGuest ? 'Tamu / offline' : (vm.email ?? '')),
        ),
        ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.logout), title: const Text('Keluar akun'), onTap: () async => vm.signOut()),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: const Text('Hapus akun & data', style: TextStyle(color: Colors.redAccent)),
          subtitle: const Text('Menghapus akun dan semua progres, termasuk di cloud.'),
          onTap: () => _confirmDelete(context, vm),
        ),
        _section('Data'),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: const Text('Hapus data game di perangkat'),
          onTap: () async {
            final ok = await _confirm(context, 'Hapus data game?', 'Level, koin, dekor, dan upgrade di perangkat ini akan dihapus.');
            if (ok && context.mounted) {
              await vm.resetLocalData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data game telah dihapus.')));
              }
            }
          },
        ),
        _section('Tentang'),
        ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Kebijakan privasi'), onTap: () => _showPrivacy(context)),
        ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.info_outline), title: const Text('Versi'), subtitle: const Text('Brewtopia $appVersion')),
      ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11.5, letterSpacing: 1.2, color: Color(0xFFFFD54F), fontWeight: FontWeight.w700)),
      );

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _confirmDelete(BuildContext context, SettingsViewModel vm) async {
    final ok = await _confirm(context, 'Hapus akun?', 'Akun dan seluruh progresmu akan dihapus permanen dan tidak dapat dikembalikan.');
    if (!ok || !context.mounted) return;
    final done = await vm.deleteAccount();
    if (!context.mounted) return;
    if (!done && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.error!)));
    }
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kebijakan Privasi'),
        content: const SingleChildScrollView(
          child: Text(
            'Brewtopia menyimpan: email & nama tampilan (Firebase Authentication), progres game dan nama kota (Firestore) untuk papan peringkat.\n\n'
            'Lokasi: dipakai hanya saat aplikasi dibuka, untuk menentukan kota dan check-in di lokasi kafe favorit. Koordinat lokasi favorit hanya tersimpan di save-mu; tidak ada pelacakan lokasi di latar belakang.\n\n'
            'Suara dialog memakai Text-to-Speech bawaan perangkat; teks tidak dikirim ke server kami.\n\n'
            'Kamu dapat menghapus akun dan seluruh data kapan saja lewat Pengaturan > Hapus akun & data.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
      ),
    );
  }
}

/// Satu baris pengaturan volume: judul, penjelasan, slider, dan persen.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, this.onEnd});
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: const Color(0xFFFFD54F)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Text('${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
          Slider(
            value: value.clamp(0.0, 1.0).toDouble(),
            onChanged: onChanged,
            onChangeEnd: onEnd == null ? null : (_) => onEnd!(),
          ),
        ]),
      );
}
