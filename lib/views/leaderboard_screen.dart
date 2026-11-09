import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/leaderboard_view_model.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaderboardViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('PERINGKAT')),
      body: Column(children: [
        if (vm.status != LeaderboardStatus.unavailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              ChoiceChip(
                label: const Text('Dunia'),
                selected: !vm.cityOnly,
                onSelected: (_) => vm.setCityOnly(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(vm.city != null ? 'Kota: ${vm.city}' : 'Kotaku'),
                selected: vm.cityOnly,
                onSelected: vm.city == null ? null : (_) => vm.setCityOnly(true),
              ),
              const Spacer(),
              IconButton(onPressed: vm.load, icon: const Icon(Icons.refresh)),
            ]),
          ),
        Expanded(child: _body(context, vm)),
      ]),
    );
  }

  Widget _body(BuildContext context, LeaderboardViewModel vm) {
    switch (vm.status) {
      case LeaderboardStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LeaderboardStatus.unavailable:
        return const _Message(Icons.cloud_off, 'Peringkat butuh Firebase.\nHubungkan project Firebase terlebih dahulu.');
      case LeaderboardStatus.error:
        return _Message(Icons.error_outline,
            'Gagal memuat peringkat.\nPeriksa internet atau index Firestore.',
            action: TextButton(onPressed: vm.load, child: const Text('Coba lagi')));
      case LeaderboardStatus.empty:
        return const _Message(Icons.emoji_events_outlined, 'Belum ada pemain. Jadilah yang pertama!');
      case LeaderboardStatus.data:
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.entries.length,
          itemBuilder: (_, i) {
            final e = vm.entries[i];
            final me = e.uid == vm.myUid;
            final medal = switch (i) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => '${i + 1}' };
            return Card(
              color: me ? const Color(0xFF8B6239) : const Color(0xFF5D4037),
              child: ListTile(
                leading: SizedBox(
                    width: 36,
                    child: Center(child: Text(medal, style: const TextStyle(fontSize: 20)))),
                title: Text(e.name + (me ? ' (kamu)' : ''),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Level ${e.level}${e.city != null ? ' • ${e.city}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 4),
                  Text('${e.totalEarned}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message(this.icon, this.text, {this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: Colors.white54),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) action!,
          ]),
        ),
      );
}
