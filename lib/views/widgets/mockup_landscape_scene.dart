import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/customer.dart';
import '../../data/models/decor.dart';
import '../../viewmodels/gameplay_view_model.dart';

/// Scene landscape dengan komposisi mengikuti mockup Brewtopia yang diberikan.
class MockupLandscapeScene extends StatelessWidget {
  const MockupLandscapeScene({super.key, required this.vm, this.onOvenTap, this.onJukeboxTap});
  final GameplayViewModel vm;
  final VoidCallback? onOvenTap;
  final VoidCallback? onJukeboxTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth, h = constraints.maxHeight;
      return AnimatedBuilder(
        animation: vm.frame,
        builder: (context, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (event) {
            final p = event.localPosition;
            if (p.dx < w * .15 && p.dy > h * .50 && p.dy < h * .90) {
              onOvenTap?.call();
            } else if (p.dx > w * .88 && p.dy > h * .55) {
              onJukeboxTap?.call();
            }
          },
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFFFDDBB), Color(0xFFFFE8D0), Color(0xFFD8A477)],
                stops: [0, .62, .63]),
            ))),
            Positioned(left: 0, right: 0, top: h * .59, height: h * .41,
              child: CustomPaint(painter: _TileFloorPainter())),
            Positioned(left: w * .035, top: h * .13, width: w * .23, height: h * .40,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF8F5838),
                  border: Border.all(color: const Color(0xFF9D633D), width: 7),
                  borderRadius: BorderRadius.circular(70),
                  boxShadow: const [BoxShadow(color: Color(0x553D2418), blurRadius: 8, offset: Offset(0, 5))]),
                child: ClipRRect(borderRadius: BorderRadius.circular(60),
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF8EC9E8), Color(0xFFE8C4AE)])))),
              )),
            Positioned(left: w * .31, top: h * .105, width: w * .22, height: h * .235,
              child: Image.asset('assets/scene/mockup/menu_board.png', fit: BoxFit.fill)),
            Positioned(right: w * .025, top: h * .13, width: w * .12, height: h * .50,
              child: Image.asset('assets/scene/mockup/door_open.png', fit: BoxFit.fill)),
            Positioned(left: w * .12, top: h * .43, width: w * .72, height: h * .34,
              child: Image.asset('assets/scene/mockup/counter.png', fit: BoxFit.fill)),
            Positioned(left: w * .43, top: h * .30, width: h * .30, height: h * .34,
              child: Image.asset(vm.baristaFemale
                ? 'assets/scene/mockup/character_female_barista.png'
                : 'assets/scene/mockup/character_male_barista.png', fit: BoxFit.contain)),
            if (vm.hasDecor(Decor.plantBig))
              Positioned(left: w * .005, bottom: h * .015, width: h * .24, height: h * .34,
                child: Image.asset('assets/scene/mockup/plant_cluster.png', fit: BoxFit.contain)),
            Positioned(right: w * .015, bottom: h * .18, width: h * .18, height: h * .35,
              child: Image.asset('assets/scene/mockup/shelf_coffee.png', fit: BoxFit.contain)),
            Positioned(right: w * .16, bottom: h * .18, width: h * .16, height: h * .29,
              child: Image.asset('assets/scene/mockup/oven_fireplace.png', fit: BoxFit.contain)),
            Positioned(right: w * .01, bottom: h * .17, width: h * .19, height: h * .28,
              child: Image.asset('assets/scene/mockup/pastry_case.png', fit: BoxFit.contain)),
            ..._tables(w, h),
            ..._customers(w, h),
            Positioned(left: w * .015, bottom: h * .015, width: h * .18, height: h * .17,
              child: Image.asset('assets/scene/mockup/plant_cluster.png', fit: BoxFit.contain)),
            Positioned(right: w * .30, top: h * .02, width: w * .10, height: h * .09,
              child: const _WarmLight()),
          ]),
        ),
      );
    });
  }

  List<Widget> _tables(double w, double h) {
    final out = <Widget>[];
    final positions = <Offset>[Offset(w * .20, h * .83), Offset(w * .54, h * .86), Offset(w * .78, h * .84)];
    final names = ['table_chair_left.png', 'table_chair_center.png', 'table_chair_right.png'];
    for (var i = 0; i < math.min(vm.tableCount, positions.length); i++) {
      final p = positions[i];
      out.add(Positioned(left: p.dx - h * .19, top: p.dy - h * .20,
        width: h * .38, height: h * .22,
        child: Image.asset('assets/scene/mockup/\${names[i]}', fit: BoxFit.contain)));
    }
    return out;
  }

  List<Widget> _customers(double w, double h) {
    const sprites = ['character_male_customer.png', 'character_female_customer.png',
      'character_glasses_customer.png', 'character_suit_customer.png',
      'character_pink_customer.png', 'character_old_customer.png'];
    final out = <Widget>[];
    var index = 0;
    for (final c in vm.customers) {
      if (c.state == CustState.seated) { index++; continue; }
      final x = w * (.12 + (index % 4) * .13);
      final y = h * (.58 + (index % 2) * .055);
      final size = h * .34;
      out.add(Positioned(left: x, top: y - size, width: size * .52, height: size,
        child: Image.asset('assets/scene/mockup/\${sprites[c.variant % sprites.length]}', fit: BoxFit.contain)));
      index++;
    }
    return out;
  }
}

class _TileFloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x44A56F49)..strokeWidth = 1;
    for (var i = 1; i < 12; i++) {
      final x = size.width * i / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant _TileFloorPainter oldDelegate) => false;
}

class _WarmLight extends StatelessWidget {
  const _WarmLight();
  @override
  Widget build(BuildContext context) => const DecoratedBox(decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [Color(0xFFFFF5D8), Color(0x00FFF5D8)]),
  ));
}
