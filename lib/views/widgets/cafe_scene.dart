import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../data/models/customer.dart';
import '../../data/models/decor.dart';
import '../../data/models/product.dart';
import '../../viewmodels/gameplay_view_model.dart';
import 'product_icon.dart';
import 'walking_sprite.dart';

/// Pemetaan koordinat scene (600 x 1300) ke layar.
class Stage {
  Stage(Size size)
      : s = max(size.width / w, size.height / 1260),
        ox = (size.width - w * max(size.width / w, size.height / 1260)) / 2;
  static const double w = 600;
  static const double h = 1300;
  final double s;
  final double ox;
  double x(double ix) => ox + ix * s;
  double y(double iy) => iy * s;
  double toX(double sx) => (sx - ox) / s;
  double toY(double sy) => sy / s;
}

/// Skala perspektif: makin ke bawah (dekat kamera) makin besar.
double perspScale(double y) => (0.62 + (y - 560) / 520 * 0.52).clamp(0.55, 1.25).toDouble();

class _Drawable {
  _Drawable(this.key, this.widget);
  final double key;
  final Widget widget;
}

/// Scene kafe pseudo-3D yang dioptimalkan:
/// - layer statis (dinding, counter) dicache lewat RepaintBoundary & hanya digeser (parallax),
/// - efek ambient (langit, lampu, debu) digambar dengan laju lebih rendah,
/// - hanya objek bergerak (pelanggan, barista, balon) yang dibangun ulang tiap frame.
class CafeScene extends StatefulWidget {
  const CafeScene({super.key, required this.vm, this.onOvenTap, this.onJukeboxTap});
  final GameplayViewModel vm;
  final VoidCallback? onOvenTap;
  final VoidCallback? onJukeboxTap;

  @override
  State<CafeScene> createState() => _CafeSceneState();
}

class _CafeSceneState extends State<CafeScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  double _tiltX = 0, _tiltY = 0, _targetX = 0, _targetY = 0;
  double _baristaX = 285;
  double _baristaLean = 0;
  int _n = 0;
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _ambient = ValueNotifier(0);
  StreamSubscription<AccelerometerEvent>? _acc;
  bool _precached = false;
  Size _size = Size.zero;

  static final List<Offset> _motes = () {
    final r = Random(7);
    return List.generate(18, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    try {
      _acc = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _targetX = (e.x / 9.8).clamp(-0.5, 0.5).toDouble();
        _targetY = ((e.y / 9.8) - 0.8).clamp(-0.5, 0.5).toDouble();
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final f in [
      'scene/wall', 'scene/counter', 'scene/door', 'scene/table_0', 'scene/table_1', 'scene/table_2',
      'scene/chair', 'scene/bin', 'people/barista_m', 'people/barista_f',
      for (var i = 0; i < 8; i++) ...['people/c${i}_body', 'people/c${i}_legL', 'people/c${i}_legR'],
      for (final p in Product.values) 'icons/${p.name}',
    ]) {
      precacheImage(AssetImage('assets/$f.png'), context);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    _time += dt;
    final f = min(1.0, dt * 5);
    _tiltX += (_targetX - _tiltX) * f;
    _tiltY += (_targetY - _tiltY) * f;
    final nt = Offset(_tiltX, _tiltY);
    if ((nt - _tilt.value).distance > 0.004) _tilt.value = nt;
    if (++_n % 3 == 0) _ambient.value = _time; // efek ambient ~20 fps

    final goal = switch (widget.vm.baristaFocus) {
      BaristaFocus.machine => 322.0,
      BaristaFocus.oven => 250.0,
      BaristaFocus.idle => 285.0,
    };
    final before = _baristaX;
    _baristaX += (goal - _baristaX) * min(1.0, dt * 4);
    _baristaLean = ((_baristaX - before) * 0.9).clamp(-0.06, 0.06).toDouble();
    widget.vm.tick(dt); // memanggil frame.tick() -> hanya layer dinamis dibangun ulang
  }

  @override
  void dispose() {
    _acc?.cancel();
    _ticker.dispose();
    _tilt.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _onTap(TapUpDetails d) {
    if (_size == Size.zero) return;
    final st = Stage(_size);
    final c = Offset(_size.width / 2, _size.height / 2);
    final p = c + (d.localPosition - c) / 1.04;
    final ux = st.toX(p.dx), uy = st.toY(p.dy);
    if (ux >= 8 && ux <= 140 && uy >= 280 && uy <= 450) {
      widget.onOvenTap?.call();
    } else if (widget.vm.hasDecor(Decor.jukebox) && ux >= 510 && ux <= 600 && uy >= 620 && uy <= 790) {
      widget.onJukeboxTap?.call();
    }
  }

  double get _hour {
    final n = DateTime.now();
    return n.hour + n.minute / 60;
  }

  ({Color tint, double night}) _daylight() {
    final h = _hour;
    if (h >= 5 && h < 7.5) return (tint: const Color(0x26FF9A4D), night: 0.3);
    if (h >= 7.5 && h < 16) return (tint: const Color(0x00000000), night: 0.0);
    if (h >= 16 && h < 18.5) return (tint: const Color(0x2EFF7A3D), night: 0.25);
    if (h >= 18.5 && h < 20) return (tint: const Color(0x483A2A7C), night: 0.7);
    return (tint: const Color(0x5E0E1C3E), night: 1.0);
  }

  // ---------- helper layer ----------
  Widget _static(double depth, Widget child) => Positioned.fill(
        child: ValueListenableBuilder<Offset>(
          valueListenable: _tilt,
          child: RepaintBoundary(child: child),
          builder: (_, t, c) => Transform.translate(offset: Offset(-t.dx * 20 * depth, -t.dy * 12 * depth), child: c),
        ),
      );

  Widget _dyn(double depth, List<Widget> Function() build) => Positioned.fill(
        child: AnimatedBuilder(
          animation: widget.vm.frame,
          builder: (_, __) {
            final t = _tilt.value;
            return Transform.translate(
              offset: Offset(-t.dx * 20 * depth, -t.dy * 12 * depth),
              child: Stack(clipBehavior: Clip.none, children: build()),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final st = Stage(_size);
      final vm = widget.vm;
      final wallRect = Rect.fromLTWH(st.ox, 0, Stage.w * st.s, Stage.h * st.s);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTap,
        child: ClipRect(
          child: Transform.scale(
            scale: 1.04,
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFB98650))),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(st, vm, _ambient))),
                ),
              ),
              // dinding + dekor belakang (statis, hanya digeser)
              _static(
                0.5,
                ListenableBuilder(
                  listenable: vm,
                  builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
                    Positioned.fromRect(
                      rect: wallRect,
                      child: Image.asset('assets/scene/wall.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
                    ),
                    ..._backDecor(st),
                    Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LightsPainter(st, vm, _ambient)))),
                  ]),
                ),
              ),
              _dyn(0.5, () => [_door(st)]),
              _dyn(1.0, () => [_barista(st)]),
              _static(
                1.0,
                Stack(clipBehavior: Clip.none, children: [
                  Positioned.fromRect(
                    rect: wallRect,
                    child: Image.asset('assets/scene/counter.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
                  ),
                ]),
              ),
              _dyn(1.0, () => [
                    ..._displayPastries(st),
                    ..._ovenHud(st),
                    ..._floorObjects(st),
                    ..._bubbles(st),
                    ..._flyers(st),
                    ..._floaters(st),
                  ]),
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(children: [
                    Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _FxPainter(st, vm, _ambient)))),
                    Positioned.fill(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _ambient,
                        builder: (_, __, ___) {
                          final l = _daylight();
                          final night = (l.night + (vm.raining ? 0.25 : 0.0)).clamp(0.0, 1.0).toDouble();
                          return Stack(children: [
                            Positioned.fill(child: ColoredBox(color: l.tint)),
                            Positioned.fill(child: CustomPaint(painter: _GlowPainter(st, night, vm.hasDecor(Decor.neon), vm.hasDecor(Decor.pendantLamps)))),
                          ]);
                        },
                      ),
                    ),
                    Positioned.fill(child: CustomPaint(painter: _MotePainter(_motes, st, _ambient))),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.1,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.33)],
                            stops: const [0.62, 1],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  // ---------------- dekor belakang ----------------
  List<Widget> _backDecor(Stage st) {
    final vm = widget.vm;
    final out = <Widget>[];
    Widget img(String name, double cx, double bottom, double w, double h) => Positioned(
          left: st.x(cx - w / 2),
          top: st.y(bottom - h),
          width: w * st.s,
          height: h * st.s,
          child: Image.asset('assets/scene/$name.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
        );
    if (vm.hasDecor(Decor.rug)) out.add(img('rug', 300, 1070, 440, 150));
    if (vm.hasDecor(Decor.frames)) out.add(img('frames', 415, 215, 60, 150));
    if (vm.hasDecor(Decor.neon)) out.add(img('neon', 510, 170, 130, 62));
    return out;
  }

  Widget _door(Stage st) {
    final open = Curves.easeInOut.transform(widget.vm.doorOpen);
    return Positioned(
      left: st.x(458),
      top: st.y(196),
      width: 116 * st.s,
      height: 352 * st.s,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateY(-open * 1.15),
        child: Image.asset('assets/scene/door.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
      ),
    );
  }

  // ---------------- barista ----------------
  Widget _barista(Stage st) {
    final vm = widget.vm;
    final working = vm.baristaFocus != BaristaFocus.idle;
    final canvas = 380 * st.s;
    final bob = sin(_time * (working ? 9 : 2)) * (working ? 3.0 : 1.5) * st.s;
    return Positioned(
      left: st.x(_baristaX) - canvas / 2,
      top: st.y(258) + bob,
      width: canvas,
      height: canvas,
      child: Transform.rotate(
        angle: _baristaLean + (working ? sin(_time * 9) * 0.02 : 0),
        alignment: const Alignment(0, 0.9),
        child: Image.asset(
          vm.baristaFemale ? 'assets/people/barista_f.png' : 'assets/people/barista_m.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  // ---------------- etalase & oven ----------------
  List<Widget> _displayPastries(Stage st) {
    final vm = widget.vm;
    final items = <Product>[];
    for (final p in Product.values.where((e) => e.isFood)) {
      for (var i = 0; i < min(vm.stockOf(p), 4); i++) {
        items.add(p);
      }
    }
    final out = <Widget>[];
    for (var i = 0; i < min(items.length, 8); i++) {
      final row = i < 4 ? 1 : 0;
      final col = i % 4;
      out.add(Positioned(
        left: st.x(150 + col * 25.0),
        top: st.y(row == 1 ? 404 : 376),
        child: ProductIcon(items[i], size: 28 * st.s),
      ));
    }
    return out;
  }

  List<Widget> _ovenHud(Stage st) {
    final vm = widget.vm;
    final out = <Widget>[];
    var shown = 0;
    for (var i = 0; i < vm.ovens.length; i++) {
      final o = vm.ovens[i];
      if (o.state == OvenState.idle) continue;
      final ready = o.state == OvenState.ready;
      final burnt = o.state == OvenState.burnt;
      final pulse = 0.5 + 0.5 * sin(_time * 8);
      out.add(Positioned(
        left: st.x(8 + shown * 64),
        top: st.y(262),
        width: 62 * st.s,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 3 * st.s, vertical: 2 * st.s),
          decoration: BoxDecoration(
            color: burnt
                ? Colors.grey.shade800
                : (ready ? Color.lerp(Colors.green.shade600, Colors.lightGreenAccent, pulse) : Colors.black.withValues(alpha: 0.68)),
            borderRadius: BorderRadius.circular(8 * st.s),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!burnt) ProductIcon(o.item!, size: 16),
              Flexible(
                child: Text(burnt ? '💨 GOSONG' : (ready ? ' SIAP! x${o.trays * 3}' : ' x${o.trays * 3}'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
            if (!burnt)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LinearProgressIndicator(
                  value: ready ? 1 - (o.readyT / 7) : o.progress,
                  minHeight: 3,
                  color: ready ? Colors.white : Colors.orangeAccent,
                  backgroundColor: Colors.white24,
                ),
              ),
          ]),
        ),
      ));
      shown++;
    }
    return out;
  }

  // ---------------- lantai: meja, kursi, pelanggan (urut kedalaman) ----------------
  List<Widget> _floorObjects(Stage st) {
    final vm = widget.vm;
    final list = <_Drawable>[];

    {
      final sc = perspScale(GameplayViewModel.binPos.dy);
      final shake = vm.binShake > 0 ? sin(_time * 40) * 0.1 * min(1.0, vm.binShake) : 0.0;
      list.add(_Drawable(
        GameplayViewModel.binPos.dy,
        Positioned(
          left: st.x(GameplayViewModel.binPos.dx - 35 * sc),
          top: st.y(GameplayViewModel.binPos.dy - 96 * sc),
          width: 70 * sc * st.s,
          height: 96 * sc * st.s,
          child: Transform.rotate(
            angle: shake,
            alignment: Alignment.bottomCenter,
            child: Image.asset('assets/scene/bin.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
          ),
        ),
      ));
    }

    void prop(String name, double cx, double by, double w, double h) {
      final sc = perspScale(by);
      list.add(_Drawable(
        by,
        Positioned(
          left: st.x(cx - w * sc / 2),
          top: st.y(by - h * sc),
          width: w * sc * st.s,
          height: h * sc * st.s,
          child: Image.asset('assets/scene/$name.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
        ),
      ));
    }

    if (vm.hasDecor(Decor.plantBig)) prop('plant_big', 48, 900, 100, 190);
    if (vm.hasDecor(Decor.plantSmall)) prop('plant_small', 562, 1020, 60, 100);
    if (vm.hasDecor(Decor.jukebox)) prop('jukebox', 560, 780, 92, 150);

    for (var i = 0; i < vm.tableCount; i++) {
      final spot = GameplayViewModel.tableSpots[i];
      final sc = perspScale(spot.dy);
      Customer? sitter;
      for (final c in vm.customers) {
        if (c.tableIndex == i && c.state == CustState.seated) sitter = c;
      }
      list.add(_Drawable(
        spot.dy - 1,
        Positioned(
          left: st.x(spot.dx - 50 * sc),
          top: st.y(spot.dy - 30 * sc - 150 * sc),
          width: 100 * sc * st.s,
          height: 150 * sc * st.s,
          child: Image.asset('assets/scene/chair.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
        ),
      ));
      if (sitter != null) {
        final c = sitter;
        final cs = 480 * sc * 0.84;
        final hip = c.variant >= 4 ? 0.72 : 0.616;
        final tableTop = spot.dy - 60 * sc;
        list.add(_Drawable(
          spot.dy - 0.5,
          Positioned(
            left: st.x(spot.dx - cs / 2),
            top: st.y(tableTop - hip * cs),
            width: cs * st.s,
            height: cs * st.s,
            child: WalkingSprite(variant: c.variant, size: cs * st.s, time: _time + c.id, seated: true, hop: c.hop, angry: c.angry),
          ),
        ));
      }
      list.add(_Drawable(
        spot.dy,
        Positioned(
          left: st.x(spot.dx - 75 * sc),
          top: st.y(spot.dy - 100 * sc),
          width: 150 * sc * st.s,
          height: 120 * sc * st.s,
          child: Image.asset('assets/scene/table_${vm.clothStyle}.png', fit: BoxFit.fill, filterQuality: FilterQuality.low),
        ),
      ));
      if (sitter != null && sitter.items.isNotEmpty) {
        final pr = sitter.items.first.product;
        list.add(_Drawable(
          spot.dy + 0.1,
          Positioned(
            left: st.x(spot.dx + 6 * sc),
            top: st.y(spot.dy - 96 * sc),
            child: ProductIcon(pr, size: 38 * sc * st.s),
          ),
        ));
      }
    }

    for (final c in vm.customers) {
      if (c.state == CustState.seated) continue;
      var key = c.y;
      if (c.state == CustState.toTable) {
        final d = (c.targetX - c.x).abs() + (c.targetY - c.y).abs();
        if (d < 70) key = GameplayViewModel.tableSpots[c.tableIndex].dy - 0.6;
      }
      final sc = perspScale(c.y);
      final cs = 432 * sc;
      final lift = c.isWalking ? max(0.0, sin(c.walkPhase).abs() - 0.6) : 0.0;
      list.add(_Drawable(
        key - 0.01,
        Positioned(
          left: st.x(c.x - cs * 0.22),
          top: st.y(c.y - cs * 0.03),
          width: cs * 0.44 * (1 - lift * 0.4) * st.s,
          height: cs * 0.07 * st.s,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.all(Radius.elliptical(cs * 0.22 * st.s, cs * 0.035 * st.s)),
            ),
          ),
        ),
      ));
      list.add(_Drawable(
        key,
        Positioned(
          left: st.x(c.x - cs / 2),
          top: st.y(c.y - 0.92 * cs),
          width: cs * st.s,
          height: cs * st.s,
          child: WalkingSprite(
            variant: c.variant,
            size: cs * st.s,
            time: _time + c.id,
            phase: c.walkPhase,
            walking: c.isWalking,
            hop: c.hop,
            angry: c.angry,
            lean: c.lean,
          ),
        ),
      ));
    }

    list.sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => e.widget).toList();
  }

  // ---------------- balon dialog & tiket pesanan ----------------
  List<Widget> _bubbles(Stage st) {
    final vm = widget.vm;
    final out = <Widget>[];
    final h = _size.height;
    final w = _size.width;
    const maxW = 210.0;

    Widget place(double cxUnits, double topUnits, Widget child) {
      final cx = st.x(cxUnits);
      final left = (cx - maxW / 2).clamp(6.0, max(6.0, w - maxW - 6)).toDouble();
      return Positioned(left: left, width: maxW, bottom: h - st.y(topUnits), child: child);
    }

    for (final c in vm.customers) {
      final seated = c.state == CustState.seated;
      final sc = perspScale(seated ? GameplayViewModel.tableSpots[c.tableIndex].dy : c.y);
      final cs = (seated ? 480 * 0.84 : 432) * sc;
      double headTop;
      double cx = c.x;
      if (seated) {
        final spot = GameplayViewModel.tableSpots[c.tableIndex];
        final hip = c.variant >= 4 ? 0.72 : 0.616;
        headTop = (spot.dy - 60 * sc - hip * cs) + 0.08 * cs;
        cx = spot.dx;
      } else {
        headTop = c.y - 0.92 * cs + 0.08 * cs;
      }
      final children = <Widget>[];
      if (c.bubble != null) children.add(_SpeechBubble(text: c.bubble!));
      if (c.state == CustState.waiting || c.state == CustState.ordering) {
        children.add(_OrderChip(customer: c, selected: vm.selectedId == c.id));
      }
      if (children.isEmpty) continue;
      out.add(place(cx, headTop - 2, Column(mainAxisSize: MainAxisSize.min, children: children)));
    }
    if (vm.baristaBubble != null) {
      out.add(place(_baristaX, 292, _SpeechBubble(text: vm.baristaBubble!, barista: true)));
    }
    return out;
  }

  List<Widget> _flyers(Stage st) {
    final out = <Widget>[];
    for (final f in widget.vm.flyers) {
      final t = Curves.easeInOut.transform(f.t.clamp(0.0, 1.0).toDouble());
      final p = Offset.lerp(f.from, f.to, t)! + Offset(0, -sin(pi * t) * (f.trash ? 90 : 55));
      final scale = f.trash ? (1 - 0.45 * t) : 1.0;
      final size = 40.0 * st.s.clamp(0.8, 1.6).toDouble();
      out.add(Positioned(
        left: st.x(p.dx) - size / 2,
        top: st.y(p.dy) - size / 2,
        child: Transform.rotate(
          angle: f.trash ? t * 9 : 0,
          child: Transform.scale(
            scale: scale,
            child: f.product != null ? ProductIcon(f.product!, size: size) : Text(f.emoji, style: TextStyle(fontSize: size * 0.8, height: 1)),
          ),
        ),
      ));
    }
    return out;
  }

  List<Widget> _floaters(Stage st) => [
        for (final f in widget.vm.floaters)
          Positioned(
            left: st.x(f.x) - 60,
            top: st.y(f.y),
            width: 120,
            child: Opacity(
              opacity: (1 - f.t).clamp(0.0, 1.0).toDouble(),
              child: Text(
                f.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19 + 5 * (1 - f.t),
                  fontWeight: FontWeight.w800,
                  color: f.color,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2))],
                ),
              ),
            ),
          ),
      ];
}

// =====================================================================================
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, this.barista = false});
  final String text;
  final bool barista;

  @override
  Widget build(BuildContext context) {
    final bg = barista ? const Color(0xFFE8F5E9) : Colors.white;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w600, color: Colors.brown.shade900),
        ),
      ),
      CustomPaint(size: const Size(12, 7), painter: _TailPainter(bg)),
    ]);
  }
}

/// Tiket pesanan: nama pelanggan + gambar & NAMA tiap item (supaya jelas apa yang harus dibuat).
class _OrderChip extends StatelessWidget {
  const _OrderChip({required this.customer, required this.selected});
  final Customer customer;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = customer.patienceFraction;
    final bar = Color.lerp(Colors.redAccent, Colors.lightGreenAccent.shade700, p)!;
    final badge = switch (customer.trait) {
      CustomerTrait.vip => ' 👑',
      CustomerTrait.critic => ' 🧐',
      CustomerTrait.impatient => ' ⏰',
      CustomerTrait.generous => ' 💝',
      CustomerTrait.normal => '',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: const Color(0xFFFFB300), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${customer.name}$badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.brown.shade700)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final it in customer.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(alignment: Alignment.center, children: [
                  ProductIcon(it.product, size: 28, dim: it.done),
                  if (it.done) const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ]),
                Text(it.product.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: it.done ? Colors.grey : Colors.brown.shade900)),
              ]),
            ),
        ]),
        const SizedBox(height: 3),
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: p, minHeight: 4, color: bar, backgroundColor: Colors.brown.shade100),
          ),
        ),
      ]),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}

// =====================================================================================
// Painter ambient: memakai `repaint` (ValueNotifier) agar digambar ~20 fps, tanpa membangun ulang widget.
Paint _glowPaint(Offset c, double r, Color color, double alpha) => Paint()
  ..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: alpha * 0.25), Colors.transparent], stops: const [0, 0.45, 1])
      .createShader(Rect.fromCircle(center: c, radius: r));

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.st, this.vm, this.time) : super(repaint: time);
  final Stage st;
  final GameplayViewModel vm;
  final ValueNotifier<double> time;

  static const _keys = <(double, Color, Color)>[
    (0, Color(0xFF0B1330), Color(0xFF1B2552)),
    (5, Color(0xFF1E2A5A), Color(0xFF6B4E7A)),
    (6.5, Color(0xFF4F6FB5), Color(0xFFF4A860)),
    (8.5, Color(0xFF6EB7F0), Color(0xFFDFF1FF)),
    (16, Color(0xFF6EB7F0), Color(0xFFDFF1FF)),
    (18, Color(0xFF5B6EB5), Color(0xFFF29B5A)),
    (19.5, Color(0xFF2A2F66), Color(0xFF8A5A8A)),
    (21, Color(0xFF0B1330), Color(0xFF1B2552)),
    (24, Color(0xFF0B1330), Color(0xFF1B2552)),
  ];

  (Color, Color) _sky(double hour) {
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i], b = _keys[i + 1];
      if (hour >= a.$1 && hour <= b.$1) {
        final u = (hour - a.$1) / (b.$1 - a.$1);
        return (Color.lerp(a.$2, b.$2, u)!, Color.lerp(a.$3, b.$3, u)!);
      }
    }
    return (_keys.first.$2, _keys.first.$3);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60;
    final t = time.value;
    final rain = vm.raining;
    final rect = Rect.fromLTWH(0, 0, size.width, st.y(548));
    var (top, bottom) = _sky(hour);
    if (rain) {
      top = Color.lerp(top, const Color(0xFF55606E), 0.6)!;
      bottom = Color.lerp(bottom, const Color(0xFF8A95A3), 0.6)!;
    }
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]).createShader(rect));
    final night = hour < 6 || hour >= 19.5;
    final c = Offset(st.x(86), st.y(150));
    if (!rain) {
      if (night) {
        canvas.drawCircle(c, 26 * st.s, _glowPaint(c, 26 * st.s, Colors.white, 0.25));
        canvas.drawCircle(c, 12 * st.s, Paint()..color = const Color(0xFFFFF6D6));
        canvas.drawCircle(c + Offset(4 * st.s, -2 * st.s), 10 * st.s, Paint()..color = top);
        for (var i = 0; i < 18; i++) {
          final p = Offset(st.x(30 + (i * 53) % 130), st.y(80 + (i * 37) % 170));
          canvas.drawCircle(p, (0.8 + (i % 3) * 0.5) * st.s, Paint()..color = Colors.white.withValues(alpha: 0.5 + 0.5 * sin(t * 2 + i)));
        }
      } else {
        final warm = hour < 8 || hour > 16.5;
        canvas.drawCircle(c, 40 * st.s, _glowPaint(c, 40 * st.s, warm ? const Color(0xFFFF9A4D) : const Color(0xFFFFF2A8), 0.5));
        canvas.drawCircle(c, 15 * st.s, Paint()..color = warm ? const Color(0xFFFFB45A) : const Color(0xFFFFE680));
      }
    }
    for (var k = 0; k < 3; k++) {
      final x = ((t * (5 + k * 2) + k * 230) % 820) - 120;
      final y = 100 + k * 55.0;
      final cp = Paint()..color = Colors.white.withValues(alpha: night ? 0.10 : (rain ? 0.5 : 0.7));
      canvas.drawOval(Rect.fromCenter(center: Offset(st.x(x), st.y(y)), width: 70 * st.s, height: 20 * st.s), cp);
      canvas.drawOval(Rect.fromCenter(center: Offset(st.x(x + 18), st.y(y - 8)), width: 44 * st.s, height: 22 * st.s), cp);
    }
    canvas.drawRect(Rect.fromLTRB(st.x(440), st.y(470), st.x(600), st.y(548)), Paint()..color = const Color(0xFF9A9288));
    canvas.drawRect(Rect.fromLTRB(st.x(440), st.y(470), st.x(600), st.y(476)), Paint()..color = const Color(0xFF7C746A));
    if (rain) {
      final rp = Paint()..color = Colors.white.withValues(alpha: 0.55)..strokeWidth = 1.2 * st.s;
      for (var i = 0; i < 50; i++) {
        final x = (i * 83) % 600 + 0.0;
        final y0 = ((t * 520 + i * 47) % 560);
        canvas.drawLine(Offset(st.x(x), st.y(y0)), Offset(st.x(x - 5), st.y(y0 + 22)), rp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.st.s != st.s || old.st.ox != st.ox;
}

class _LightsPainter extends CustomPainter {
  _LightsPainter(this.st, this.vm, this.time) : super(repaint: time);
  final Stage st;
  final GameplayViewModel vm;
  final ValueNotifier<double> time;

  void _lamp(Canvas canvas, double x, double shadeY, double w, Color shade) {
    final cord = Paint()..color = const Color(0xFF3A2A20)..strokeWidth = 1.6 * st.s;
    canvas.drawLine(Offset(st.x(x), 0), Offset(st.x(x), st.y(shadeY - 24)), cord);
    final path = Path()
      ..moveTo(st.x(x - w * 0.28), st.y(shadeY - 24))
      ..lineTo(st.x(x + w * 0.28), st.y(shadeY - 24))
      ..lineTo(st.x(x + w * 0.5), st.y(shadeY))
      ..lineTo(st.x(x - w * 0.5), st.y(shadeY))
      ..close();
    canvas.drawPath(path, Paint()..color = shade);
    canvas.drawOval(Rect.fromCenter(center: Offset(st.x(x), st.y(shadeY + 1)), width: w * 0.6 * st.s, height: 7 * st.s), Paint()..color = const Color(0xFFFFF1B8));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    _lamp(canvas, 172, 150, 44, const Color(0xFFE9A93A));
    _lamp(canvas, 372, 132, 44, const Color(0xFFE9A93A));
    if (vm.hasDecor(Decor.pendantLamps)) {
      for (final x in [105.0, 300.0, 495.0]) {
        _lamp(canvas, x, 640, 56, const Color(0xFFC26A40));
      }
    }
    if (vm.hasDecor(Decor.stringLights)) {
      const cols = [Color(0xFFFFD54F), Color(0xFFFF8A80), Color(0xFF80D8FF), Color(0xFFB9F6CA)];
      for (var seg = 0; seg < 3; seg++) {
        final x0 = seg * 200.0, x1 = x0 + 200;
        final p = Path()..moveTo(st.x(x0), st.y(14));
        p.quadraticBezierTo(st.x((x0 + x1) / 2), st.y(52), st.x(x1), st.y(14));
        canvas.drawPath(p, Paint()..color = const Color(0xFF3A2A20)..style = PaintingStyle.stroke..strokeWidth = 1.3 * st.s);
        for (var i = 1; i < 9; i++) {
          final u = i / 9;
          final x = x0 + 200 * u;
          final y = 14 + 38 * 2 * u * (1 - u) * 0.95;
          final tw = 0.6 + 0.4 * sin(t * 3 + i + seg);
          final col = cols[(i + seg) % 4];
          final c = Offset(st.x(x), st.y(y + 4));
          canvas.drawCircle(c, 8 * st.s, _glowPaint(c, 8 * st.s, col, 0.5 * tw));
          canvas.drawCircle(c, 2.6 * st.s, Paint()..color = col.withValues(alpha: 0.5 + 0.5 * tw));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LightsPainter old) => old.st.s != st.s || old.st.ox != st.ox;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.st, this.night, this.neon, this.pendants);
  final Stage st;
  final double night;
  final bool neon;
  final bool pendants;

  void _glow(Canvas canvas, double x, double y, double r, Color c, double a) {
    final center = Offset(st.x(x), st.y(y));
    canvas.drawCircle(center, r * st.s, _glowPaint(center, r * st.s, c, a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = 0.22 + 0.34 * night;
    _glow(canvas, 172, 160, 150, const Color(0xFFFFD27A), a);
    _glow(canvas, 372, 142, 160, const Color(0xFFFFD27A), a);
    _glow(canvas, 72, 392, 90, const Color(0xFFFF8A3D), 0.10 + 0.12 * night);
    if (pendants) {
      for (final x in [105.0, 300.0, 495.0]) {
        _glow(canvas, x, 700, 130, const Color(0xFFFFC27A), a * 0.9);
      }
    }
    if (neon) _glow(canvas, 510, 170, 110, const Color(0xFFFF5A9F), 0.16 + 0.22 * night);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.night != night || old.neon != neon || old.pendants != pendants || old.st.s != st.s;
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.st, this.vm, this.time) : super(repaint: time);
  final Stage st;
  final GameplayViewModel vm;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final machine = vm.baristaFocus == BaristaFocus.machine;
    final intensity = machine ? 1.0 : 0.3;
    for (var i = 0; i < 5; i++) {
      final p = (t * (machine ? 0.6 : 0.3) + i / 5) % 1.0;
      final c = Offset(st.x(395 + sin((p + i) * 5.5) * 9 * (0.5 + p)), st.y(372 - p * 80));
      final r = (6 + p * 12) * st.s;
      canvas.drawCircle(c, r, _glowPaint(c, r, Colors.white, (1 - p) * 0.5 * intensity));
    }
    final baking = vm.ovens.any((o) => o.state == OvenState.baking || o.state == OvenState.ready);
    if (baking) {
      final glow = 0.6 + 0.4 * sin(t * 6);
      final c = Offset(st.x(72), st.y(396));
      canvas.drawCircle(c, 36 * st.s, _glowPaint(c, 36 * st.s, const Color(0xFFFF9A3D), 0.6 * glow));
      for (var i = 0; i < 4; i++) {
        final p = (t * 0.35 + i / 4) % 1.0;
        final cc = Offset(st.x(97 + sin((p + i) * 4) * 7), st.y(286 - p * 70));
        final r = (5 + p * 11) * st.s;
        canvas.drawCircle(cc, r, _glowPaint(cc, r, Colors.grey, (1 - p) * 0.45));
      }
    }
    if (vm.ovens.any((o) => o.state == OvenState.burnt)) {
      for (var i = 0; i < 5; i++) {
        final p = (t * 0.7 + i / 5) % 1.0;
        final cc = Offset(st.x(97 + sin((p + i) * 3) * 10), st.y(286 - p * 90));
        final r = (7 + p * 16) * st.s;
        canvas.drawCircle(cc, r, _glowPaint(cc, r, Colors.black, (1 - p) * 0.55));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => old.st.s != st.s;
}

class _MotePainter extends CustomPainter {
  _MotePainter(this.motes, this.st, this.time) : super(repaint: time);
  final List<Offset> motes;
  final Stage st;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (var i = 0; i < motes.length; i++) {
      final m = motes[i];
      final x = (m.dx + sin(t * 0.3 + i) * 0.03) * size.width;
      final y = ((m.dy + t * 0.012 * (1 + i % 3)) % 1.0) * size.height * 0.7;
      final tw = 0.5 + 0.5 * sin(t * 1.6 + i * 1.3);
      canvas.drawCircle(Offset(x, y), (1.1 + (i % 3)) * (st.s + 0.3), Paint()..color = const Color(0xFFFFF1C2).withValues(alpha: 0.16 * tw));
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.st.s != st.s;
}
