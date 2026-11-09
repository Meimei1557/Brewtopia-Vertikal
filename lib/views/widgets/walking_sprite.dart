import 'dart:math';
import 'package:flutter/material.dart';

/// Karakter 2.5D dari 3 layer (kaki kiri, kaki kanan, badan).
/// Berjalan: kaki terangkat bergantian, badan naik-turun & miring.
/// Duduk (`seated`): hanya badan, napas halus. Diam: napas + goyang kecil.
class WalkingSprite extends StatelessWidget {
  const WalkingSprite({
    super.key,
    required this.variant,
    required this.size,
    required this.time,
    this.phase = 0,
    this.walking = false,
    this.seated = false,
    this.hop = 0,
    this.angry = false,
    this.lean = 0,
  });

  final int variant; // 0..3 pria, 4..7 wanita
  final double size; // sisi kanvas sprite (piksel layar)
  final double time;
  final double phase;
  final bool walking;
  final bool seated;
  final double hop;
  final bool angry;
  final double lean;

  Widget _layer(String part) => Image.asset(
        'assets/people/c${variant}_$part.png',
        width: size,
        height: size,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    final k = size / 500;
    final female = variant >= 4;
    final pivot = female ? const Offset(248, 396) : const Offset(250, 308);
    final s = sin(phase);

    final bob = walking ? -s.abs() * 7 * k : sin(time * 2.2) * 0.9 * k;
    final sway = walking ? s * 0.035 + lean : (seated ? sin(time * 1.3) * 0.012 : sin(time * 1.1) * 0.01);
    final scaleY = walking ? 1 - 0.015 * s.abs() : 1 + sin(time * 2.2) * 0.012;
    final hopY = -sin(hop.clamp(0.0, 1.0) * pi) * 34 * k;

    final liftL = walking ? max(0.0, s) * 12 * k : 0.0;
    final liftR = walking ? max(0.0, -s) * 12 * k : 0.0;
    final rotL = walking ? -max(0.0, s) * 0.12 : 0.0;
    final rotR = walking ? max(0.0, -s) * 0.12 : 0.0;
    final pivotAlign = Alignment(pivot.dx / 250 - 1, pivot.dy / 250 - 1);

    Widget leg(String part, double lift, double rot) => Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.rotate(angle: rot, alignment: pivotAlign, child: _layer(part)),
        );

    Widget figure = SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        if (!seated) leg('legL', liftL, rotL),
        if (!seated) leg('legR', liftR, rotR),
        _layer('body'),
      ]),
    );

    if (angry) {
      figure = ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.red.withValues(alpha: 0.28), BlendMode.srcATop),
        child: figure,
      );
    }

    return Transform.translate(
      offset: Offset(0, bob + hopY),
      child: Transform.rotate(
        angle: sway,
        alignment: const Alignment(0, 0.84),
        child: Transform.scale(scaleY: scaleY, alignment: const Alignment(0, 0.84), child: figure),
      ),
    );
  }
}
