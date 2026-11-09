import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../viewmodels/gameplay_view_model.dart';

class MockupTopBar extends StatefulWidget {
  const MockupTopBar({super.key, required this.vm});
  final GameplayViewModel vm;
  @override
  State<MockupTopBar> createState() => _MockupTopBarState();
}

class _MockupTopBarState extends State<MockupTopBar> {
  bool paused = false;
  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    Widget pill(Widget child, {double? width}) => Container(
      width: width, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFF75452E), borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB77A4C), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x553D2418), blurRadius: 4, offset: Offset(0, 2))]),
      child: child);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        pill(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Lv ${vm.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 3),
          SizedBox(width: 85, child: ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: vm.xpTarget == 0 ? 0 : (vm.xp / vm.xpTarget).clamp(0.0, 1.0),
              minHeight: 7, color: const Color(0xFFFFC52E), backgroundColor: const Color(0xFF4C2B1D)))),
        ])),
        const SizedBox(width: 8),
        pill(Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.monetization_on, color: Color(0xFFFFC52E), size: 22),
          const SizedBox(width: 6),
          Text('${vm.money}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8), const Icon(Icons.add_circle, color: Color(0xFFFFB04A), size: 22),
        ])),
        const SizedBox(width: 8),
        Expanded(child: pill(AnimatedBuilder(animation: vm.frame, builder: (_, __) =>
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.access_time_filled, color: Color(0xFFFFE6C6), size: 20),
            const SizedBox(width: 8),
            Text(vm.phase == DayPhase.open ? 'Hari ${vm.day} • ${vm.dayLeft.ceil()}s' : 'Hari ${vm.day} • Tutup',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ])))),
        const SizedBox(width: 8),
        pill(Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star, color: Color(0xFFFFC52E), size: 22), const SizedBox(width: 4),
          Text(vm.reputation.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        ])),
        const SizedBox(width: 8),
        _roundButton(Icons.settings, () => context.push(Routes.settings)),
        const SizedBox(width: 6),
        _roundButton(paused ? Icons.play_arrow : Icons.pause, () {
          setState(() => paused = !paused);
          if (paused) vm.pause(); else vm.resume();
        }),
      ]),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xFF75452E), shape: const CircleBorder(),
    child: InkWell(onTap: onTap, customBorder: const CircleBorder(),
      child: Container(width: 42, height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB77A4C), width: 2)),
        child: Icon(icon, color: const Color(0xFFFFEBD4), size: 23))),
  );
}

class MockupBottomBar extends StatelessWidget {
  const MockupBottomBar({super.key, required this.onShop, required this.onOven});
  final void Function([int]) onShop;
  final VoidCallback onOven;
  @override
  Widget build(BuildContext context) {
    final buttons = <(String, VoidCallback)>[
      ('button_shop.png', () => onShop(0)),
      ('button_ingredients.png', () => onShop(1)),
      ('button_oven.png', onOven),
      ('button_products.png', () => onShop(2)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        for (final item in buttons)
          Padding(padding: const EdgeInsets.only(right: 8),
            child: SizedBox(width: 82, height: 76,
              child: Material(color: Colors.transparent,
                child: InkWell(onTap: item.$2, borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/scene/mockup/${item.$1}', fit: BoxFit.contain)))),
      ]),
    );
  }
}
