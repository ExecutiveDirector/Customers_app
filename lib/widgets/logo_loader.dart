import 'dart:math' as math;
import 'package:flutter/material.dart';

/// AquaGas logo loader: a gradient ring spins around the logo while the logo
/// itself breathes in and out. Use it wherever products or pages are loading.
class LogoLoader extends StatefulWidget {
  const LogoLoader({super.key, this.size = 96, this.label});

  final double size;
  final String? label;

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: s,
          height: s,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final pulse = 0.92 + 0.08 * math.sin(_c.value * 2 * math.pi);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning gradient arc.
                  Transform.rotate(
                    angle: _c.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size.square(s),
                      painter: _RingPainter(),
                    ),
                  ),
                  // Breathing logo.
                  Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: s * 0.78,
                      height: s * 0.78,
                      padding: EdgeInsets.all(s * 0.08),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.water_drop,
                          size: s * 0.4,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ),
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
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0x0000A651), Color(0xFF1E88E5), Color(0xFF00A651)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect.deflate(stroke), 0, math.pi * 1.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
