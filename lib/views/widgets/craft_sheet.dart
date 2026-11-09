import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/di.dart';
import '../../core/audio_service.dart';
import '../../data/models/product.dart';
import 'product_icon.dart';

/// Mini-game meracik / membuat adonan.
/// Ketuk cepat (giling, uleni) atau TAHAN lalu LEPAS di zona hijau (seduh, uap, tuang, lipat, glasir).
/// Hasil kualitas 0..1 dikembalikan lewat Navigator.pop; tombol X = batal (mengembalikan null).
class CraftSheet extends StatefulWidget {
  const CraftSheet({super.key, required this.product, required this.machineLevel});
  final Product product;
  final double machineLevel;

  @override
  State<CraftSheet> createState() => _CraftSheetState();
}

class _CraftSheetState extends State<CraftSheet> with SingleTickerProviderStateMixin {
  final AudioService _audio = getIt<AudioService>();
  late final List<CraftStep> _steps = widget.product.steps;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  int _idx = 0;
  final List<double> _scores = [];
  double _meter = 0;
  bool _holding = false;
  int _taps = 0;
  double _stepTime = 0;
  double _feedbackT = 0;
  String _feedback = '';
  Color _feedbackColor = Colors.white;
  bool _waitingNext = false;
  bool _finished = false;
  double _result = 0;
  double _finishT = 0;
  bool _closed = false;

  CraftStep get _step => _steps[_idx];
  bool get _isTap => _step == CraftStep.grind || _step == CraftStep.knead;
  int get _tapTarget => max(8, (_step == CraftStep.knead ? 16 : 14) - widget.machineLevel.toInt());

  ({double speed, double center, double half}) get _cfg {
    final ml = widget.machineLevel;
    return switch (_step) {
      CraftStep.extract => (speed: 0.55, center: 0.67, half: 0.08 + 0.02 * ml),
      CraftStep.pour => (speed: 0.75, center: 0.78, half: 0.07 + 0.015 * ml),
      CraftStep.steam => (speed: 0.65, center: 0.71, half: 0.08 + 0.02 * ml),
      CraftStep.shape => (speed: 0.6, center: 0.72, half: 0.08 + 0.015 * ml),
      CraftStep.glaze => (speed: 0.8, center: 0.62, half: 0.09 + 0.015 * ml),
      _ => (speed: 0.0, center: 0.0, half: 0.0),
    };
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audio.stopLong();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    if (_closed) return;
    _time += dt;
    setState(() {
      if (_finished) {
        _finishT += dt;
        if (_finishT > 1.3) _close(_result);
        return;
      }
      if (_waitingNext) {
        _feedbackT -= dt;
        if (_feedbackT <= 0) _nextStep();
        return;
      }
      _stepTime += dt;
      if (_isTap) {
        _meter = (_taps / _tapTarget).clamp(0.0, 1.0).toDouble();
        if (_taps >= _tapTarget) {
          _endStep((1.0 - max(0.0, _stepTime - 2.5) * 0.12).clamp(0.55, 1.0).toDouble());
        } else if (_stepTime > 5.0) {
          _endStep(_meter * 0.6);
        }
      } else if (_holding) {
        _meter = min(1.0, _meter + dt * _cfg.speed);
        if (_meter >= 1.0) _release();
      }
    });
  }

  void _close(double? q) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(q);
  }

  void _tapAction() {
    if (_waitingNext || _finished || !_isTap) return;
    _taps++;
    if (_taps == 1 || _taps % 7 == 0) {
      _audio.play(_step == CraftStep.grind ? Sfx.grind : Sfx.pop, gain: 0.8);
    } else {
      _audio.play(Sfx.tap, gain: 0.35);
    }
  }

  void _press() {
    if (_waitingNext || _finished || _isTap || _holding) return;
    setState(() => _holding = true);
    final s = switch (_step) {
      CraftStep.extract => Sfx.brew,
      CraftStep.pour => Sfx.pour,
      CraftStep.steam => Sfx.steam,
      _ => null,
    };
    if (s != null) _audio.playLong(s);
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    _audio.stopLong();
    final c = _cfg;
    final d = (_meter - c.center).abs();
    final score = _meter < 0.1
        ? 0.0
        : (d <= c.half ? 1 - 0.12 * (d / c.half) : (0.88 - (d - c.half) / 0.3 * 0.88).clamp(0.0, 0.88).toDouble());
    _endStep(score);
  }

  void _endStep(double score) {
    _scores.add(score);
    _holding = false;
    _audio.stopLong();
    if (score >= 0.85) {
      _feedback = 'SEMPURNA!';
      _feedbackColor = const Color(0xFFFFD54F);
      _audio.play(Sfx.perfect, gain: 0.7);
    } else if (score >= 0.6) {
      _feedback = 'Bagus!';
      _feedbackColor = Colors.lightGreenAccent;
      _audio.play(Sfx.pop);
    } else if (score >= 0.35) {
      _feedback = 'Kurang pas';
      _feedbackColor = Colors.orangeAccent;
    } else {
      _feedback = 'Gagal';
      _feedbackColor = Colors.redAccent;
      _audio.play(Sfx.error, gain: 0.6);
    }
    _waitingNext = true;
    _feedbackT = 0.75;
  }

  void _nextStep() {
    _waitingNext = false;
    if (_idx + 1 >= _steps.length) {
      _result = _scores.reduce((a, b) => a + b) / _scores.length;
      _finished = true;
      _finishT = 0;
      return;
    }
    _idx++;
    _meter = 0;
    _taps = 0;
    _stepTime = 0;
  }

  String get _ratingLabel => _result >= 0.85 ? 'SEMPURNA!' : (_result >= 0.6 ? 'Bagus!' : (_result >= 0.35 ? 'Lumayan' : 'Gagal'));

  String get _instruction => switch (_step) {
        CraftStep.grind => 'Ketuk tombol cepat-cepat untuk menggiling biji kopi!',
        CraftStep.knead => 'Ketuk cepat untuk menguleni adonan!',
        CraftStep.extract => 'TAHAN untuk menyeduh. LEPAS saat penanda masuk zona hijau.',
        CraftStep.pour => 'TAHAN untuk menuang. LEPAS saat pas di zona hijau.',
        CraftStep.steam => 'TAHAN untuk memanaskan susu. LEPAS di zona hijau.',
        CraftStep.shape => 'TAHAN untuk melipat adonan. LEPAS di zona hijau.',
        CraftStep.glaze => 'TAHAN untuk menuang glasir. LEPAS di zona hijau.',
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            ProductIcon(widget.product, size: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.product.isFood ? 'Membuat ${widget.product.label}' : 'Meracik ${widget.product.label}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Batalkan',
              onPressed: () => _close(null),
              icon: const Icon(Icons.close),
            ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.product.recipe, style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFD54F))),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 5, runSpacing: 5, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < _steps.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: i < _scores.length ? Colors.green.shade700 : (i == _idx && !_finished ? const Color(0xFF8B6239) : Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${i < _scores.length ? '✔' : _steps[i].emoji} ${_steps[i].label}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          SizedBox(height: 150, child: _finished ? _resultView() : Row(children: [
            SizedBox(width: 112, child: _visual()),
            const SizedBox(width: 10),
            Expanded(child: _stepInfo()),
          ])),
          const SizedBox(height: 8),
          if (!_finished && !_waitingNext) _bigButton(),
        ]),
      ),
    );
  }

  Widget _visual() {
    if (widget.product.isFood) {
      final progress = ((_scores.length + _meter) / _steps.length).clamp(0.0, 1.0).toDouble();
      return Center(
        child: Transform.scale(
          scale: 0.6 + 0.4 * progress + (_holding || (_isTap && _taps > 0) ? sin(_time * 14) * 0.03 : 0),
          child: ProductIcon(widget.product, size: 104),
        ),
      );
    }
    return CustomPaint(painter: _CupPainter(widget.product, _steps, _idx, _scores.length, _meter, _holding, _time));
  }

  Widget _resultView() => Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ProductIcon(widget.product, size: 90),
          const SizedBox(width: 14),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_ratingLabel, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _result >= 0.85 ? const Color(0xFFFFD54F) : Colors.white)),
            Text('Kualitas ${(_result * 100).round()}%', style: const TextStyle(color: Colors.white70)),
          ]),
        ]),
      );

  Widget _stepInfo() {
    if (_waitingNext) {
      return Center(
        child: Text(_feedback,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _feedbackColor, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_step.emoji} ${_step.label}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(_instruction, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3)),
      const Spacer(),
      if (_isTap) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: _meter, minHeight: 12, color: const Color(0xFFFFB300), backgroundColor: Colors.white12),
        ),
        const SizedBox(height: 4),
        Text('Ketukan $_taps/$_tapTarget • sisa ${max(0.0, 5 - _stepTime).toStringAsFixed(1)} dtk', style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      ] else
        _zoneBar(),
    ]);
  }

  Widget _zoneBar() {
    final c = _cfg;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: 34,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(top: 6, bottom: 6, child: Container(decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)))),
          Positioned(
            left: (c.center - c.half) * w,
            width: c.half * 2 * w,
            top: 6,
            bottom: 6,
            child: Container(decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6))),
          ),
          Positioned(left: 0, width: _meter * w, top: 12, height: 10, child: Container(decoration: BoxDecoration(color: const Color(0xFFFFB300), borderRadius: BorderRadius.circular(5)))),
          Positioned(left: _meter * w - 3, top: 0, width: 6, height: 34, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)))),
        ]),
      );
    });
  }

  Widget _bigButton() {
    final shake = _isTap && _taps > 0 ? sin(_time * 40) * 3 : 0.0;
    final label = _isTap ? 'KETUK!' : 'TAHAN';
    final grad = _holding ? const [Color(0xFFFF8A3D), Color(0xFFC0392B)] : const [Color(0xFFD9A25E), Color(0xFF8B6239)];
    return Listener(
      onPointerDown: (_) {
        if (_isTap) {
          setState(_tapAction);
        } else {
          _press();
        }
      },
      onPointerUp: (_) {
        if (!_isTap) setState(_release);
      },
      onPointerCancel: (_) {
        if (!_isTap) setState(_release);
      },
      child: Transform.translate(
        offset: Offset(shake, 0),
        child: AnimatedScale(
          scale: _holding ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: double.infinity,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: grad),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_step.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Gelas yang terisi per lapisan sesuai resep (espresso, air, susu, busa) supaya tiap kopi berbeda.
class _CupPainter extends CustomPainter {
  _CupPainter(this.product, this.steps, this.idx, this.done, this.meter, this.holding, this.t);
  final Product product;
  final List<CraftStep> steps;
  final int idx;
  final int done;
  final double meter;
  final bool holding;
  final double t;

  List<(CraftStep, Color, double)> get _layers => switch (product) {
        Product.espresso => const [(CraftStep.extract, Color(0xFF3A200F), 0.55)],
        Product.americano => const [(CraftStep.extract, Color(0xFF3A200F), 0.25), (CraftStep.pour, Color(0xFF8A5A36), 0.5)],
        Product.macchiato => const [(CraftStep.extract, Color(0xFF3A200F), 0.32), (CraftStep.steam, Color(0xFFF5EBDD), 0.2)],
        Product.cappuccino => const [(CraftStep.extract, Color(0xFF3A200F), 0.26), (CraftStep.steam, Color(0xFFE6CBA3), 0.3), (CraftStep.steam, Color(0xFFFFF8EE), 0.18)],
        Product.latte => const [(CraftStep.extract, Color(0xFF3A200F), 0.2), (CraftStep.steam, Color(0xFFD9B88C), 0.42), (CraftStep.pour, Color(0xFFFFF8EE), 0.16)],
        _ => const [],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const topW = 92.0, botW = 66.0, h = 120.0;
    final top = (size.height - h) / 2 + 6;
    final path = Path()
      ..moveTo(cx - topW / 2, top)
      ..lineTo(cx + topW / 2, top)
      ..lineTo(cx + botW / 2, top + h)
      ..lineTo(cx - botW / 2, top + h)
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(path, Paint()..color = const Color(0x33FFFFFF));
    canvas.save();
    canvas.clipPath(path);
    var filled = 0.0;
    for (final l in _layers) {
      final sIdx = steps.indexOf(l.$1);
      double frac;
      if (sIdx < done) {
        frac = 1;
      } else if (sIdx == idx && l.$1 != CraftStep.grind) {
        frac = meter;
      } else {
        frac = 0;
      }
      final hh = l.$3 * h * frac;
      if (hh <= 0) continue;
      final y1 = top + h - filled * h;
      final rect = Rect.fromLTRB(cx - topW / 2 - 4, y1 - hh, cx + topW / 2 + 4, y1);
      canvas.drawRect(rect, Paint()..color = l.$2);
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + 3), Paint()..color = Colors.white.withValues(alpha: 0.25));
      filled += l.$3 * frac;
    }
    canvas.restore();
    canvas.drawPath(path, Paint()..color = const Color(0xFFBFD6DC)..style = PaintingStyle.stroke..strokeWidth = 2.4);
    canvas.drawLine(Offset(cx - topW / 2 + 9, top + 8), Offset(cx - botW / 2 + 8, top + h - 10), Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 3);
    if (holding) {
      for (var i = 0; i < 3; i++) {
        final p = (t * 0.8 + i / 3) % 1.0;
        canvas.drawCircle(Offset(cx - 12 + i * 12 + sin(t * 4 + i) * 3, top - 4 - p * 22), 3 + p * 4, Paint()..color = Colors.white.withValues(alpha: (1 - p) * 0.5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CupPainter old) => true;
}
