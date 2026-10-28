import 'dart:math' as math;
import 'package:flutter/material.dart';

/// AquaGas animated logo loader — the same animation as the website's
/// LogoLoader: a colour ring spins around the logo while the letters of
/// "AquaGas" flip one after another, the wave ripples and a shine sweeps
/// across. Uses the website's own slices (assets/loader/l0..l6.png, wave.png).
///
///   LogoLoader()                       // 96 px
///   LogoLoader(size: 104, label: '…')  // with a caption
class LogoLoader extends StatefulWidget {
  const LogoLoader({super.key, this.size = 96, this.label});

  final double size;
  final String? label;

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

// Wordmark slices, in source pixels (same numbers as the website).
const List<List<double>> _letters = [
  [30, 173],
  [203, 135],
  [338, 124],
  [462, 136],
  [598, 143],
  [741, 121],
  [862, 138],
];
const double _srcW = 1020;
const double _srcH = 370;
const double _cut = 215; // letters above this line, the wave below it
const int _waveStrips = 28;

const List<String> _assets = [
  'assets/loader/l0.png',
  'assets/loader/l1.png',
  'assets/loader/l2.png',
  'assets/loader/l3.png',
  'assets/loader/l4.png',
  'assets/loader/l5.png',
  'assets/loader/l6.png',
  'assets/loader/wave.png',
];

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  // One 7.2 s master clock: the ring (1.2 s), the letter flip + shine (2.4 s)
  // and the wave (1.2 s) all divide it evenly, so the loop is seamless.
  static const double _cycleSeconds = 7.2;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Avoid a blank first frame while the slices decode.
    for (final a in _assets) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Letter flip keyframes (website: agl-flip). Returns [scaleX, translateY
  /// as a fraction of the letter height] for progress p in 0..1.
  static List<double> _flip(double p) {
    const kf = <List<double>>[
      [0.0, 1.0, 0.0],
      [0.075, 0.05, -0.06],
      [0.15, 1.0, -0.10],
      [0.225, 0.05, -0.05],
      [0.30, 1.0, 0.0],
      [1.0, 1.0, 0.0],
    ];
    for (var i = 0; i < kf.length - 1; i++) {
      if (p <= kf[i + 1][0]) {
        final local = (p - kf[i][0]) / (kf[i + 1][0] - kf[i][0]);
        final e = Curves.easeInOut.transform(local.clamp(0.0, 1.0).toDouble());
        return [
          kf[i][1] + (kf[i + 1][1] - kf[i][1]) * e,
          kf[i][2] + (kf[i + 1][2] - kf[i][2]) * e,
        ];
      }
    }
    return const [1.0, 0.0];
  }

  Widget _wordmark(double s, double t, bool still) {
    final disc = s * 0.84;
    final wmW = disc * 0.8;
    final wmH = wmW * _srcH / _srcW;
    final letterH = wmH * _cut / _srcH;
    final waveH = wmH - letterH;
    final stripW = wmW / _waveStrips;

    final children = <Widget>[];

    for (var i = 0; i < _letters.length; i++) {
      double sx = 1, ty = 0;
      if (!still) {
        final local = (((t - i * 0.13) % 2.4) + 2.4) % 2.4 / 2.4;
        final f = _flip(local);
        sx = f[0];
        ty = f[1];
      }
      children.add(Positioned(
        left: _letters[i][0] / _srcW * wmW,
        top: 0,
        width: _letters[i][1] / _srcW * wmW,
        height: letterH,
        child: Transform.translate(
          offset: Offset(0, ty * letterH),
          child: Transform.scale(
            scaleX: sx,
            scaleY: 1,
            alignment: const Alignment(0, 0.2), // 50% 60%
            child: Image.asset(
              'assets/loader/l$i.png',
              fit: BoxFit.fill,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ));
    }

    for (var i = 0; i < _waveStrips; i++) {
      double dy = 0;
      if (!still) {
        final q = ((t + i * 0.09) % 1.2) / 1.2;
        dy = -0.035 * math.cos(2 * math.pi * q) * waveH;
      }
      children.add(Positioned(
        left: i * stripW,
        top: letterH,
        width: stripW + 0.6,
        height: waveH,
        child: Transform.translate(
          offset: Offset(0, dy),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: wmW,
              maxWidth: wmW,
              minHeight: waveH,
              maxHeight: waveH,
              child: Transform.translate(
                offset: Offset(-i * stripW, 0),
                child: Image.asset(
                  'assets/loader/wave.png',
                  width: wmW,
                  height: waveH,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ));
    }

    if (!still) {
      final p = (t % 2.4) / 2.4;
      final dx = p < 0.6
          ? -1.2 + 2.4 * Curves.easeInOut.transform(p / 0.6)
          : 1.2;
      children.add(Positioned.fill(
        child: IgnorePointer(
          child: FractionalTranslation(
            translation: Offset(dx, 0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1, -0.3),
                  end: Alignment(1, 0.3),
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0xBFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0.4, 0.5, 0.6],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return SizedBox(
      width: wmW,
      height: wmH,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ringThickness = math.max(3.0, (s * 0.05).roundToDouble());

    return Semantics(
      label: 'Loading',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: s,
            height: s,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * _cycleSeconds;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Spinning colour ring (3 s per turn when motion is reduced).
                    Transform.rotate(
                      angle: t / (still ? 3.0 : 1.2) * 2 * math.pi,
                      child: CustomPaint(
                        size: Size.square(s),
                        painter: _RingPainter(ringThickness),
                      ),
                    ),
                    // White disc holding the animated wordmark.
                    Container(
                      width: s * 0.84,
                      height: s * 0.84,
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _wordmark(s, t, still),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.label!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Website ring: a conic gradient teal → blue → green that fades out at 84%.
class _RingPainter extends CustomPainter {
  _RingPainter(this.thickness);
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..shader = const SweepGradient(
        colors: [
          Color(0x0000A651),
          Color(0xFF00BCD4),
          Color(0xFF1E88E5),
          Color(0xFF00A651),
          Color(0x0000A651),
        ],
        stops: [0.0, 0.30, 0.60, 0.84, 0.842],
      ).createShader(rect);
    canvas.drawArc(rect.deflate(thickness / 2), 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.thickness != thickness;
}
