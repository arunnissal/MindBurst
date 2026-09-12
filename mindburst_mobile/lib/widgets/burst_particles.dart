import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParticleItem {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;
  int shapeType; // 0: circle, 1: star/sparkle, 2: diamond

  ParticleItem({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
    required this.shapeType,
  });
}

class BurstParticleController {
  _BurstParticleOverlayState? _state;

  void trigger({Offset? origin}) {
    _state?.trigger(origin: origin);
  }
}

class BurstParticleOverlay extends StatefulWidget {
  final BurstParticleController controller;
  final Widget child;

  const BurstParticleOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<BurstParticleOverlay> createState() => _BurstParticleOverlayState();
}

class _BurstParticleOverlayState extends State<BurstParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<ParticleItem> _particles = [];
  final Random _rand = Random();
  Offset _origin = Offset.zero;

  static const List<Color> _particleColors = [
    AppTheme.goldAccent,
    AppTheme.primary,
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF43F5E), // Rose
    Color(0xFF10B981), // Emerald
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..addListener(() {
        _updateParticles();
        setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant BurstParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller._state = this;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void trigger({Offset? origin}) {
    final size = MediaQuery.of(context).size;
    _origin = origin ?? Offset(size.width / 2, size.height * 0.75);

    _particles.clear();
    // Spawn 36 vibrant particles radiating in all directions
    for (int i = 0; i < 36; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = 3.0 + _rand.nextDouble() * 8.5;
      _particles.add(
        ParticleItem(
          x: _origin.dx,
          y: _origin.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 1.5, // subtle upward drift
          size: 4.0 + _rand.nextDouble() * 6.5,
          alpha: 1.0,
          color: _particleColors[_rand.nextInt(_particleColors.length)],
          shapeType: _rand.nextInt(3),
        ),
      );
    }

    _animController.forward(from: 0.0);
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.94; // air resistance
      p.vy *= 0.94;
      p.vy += 0.22; // gravity pull
      p.alpha = (1.0 - _animController.value).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _animController.isAnimating
          ? _ParticlePainter(
              particles: _particles,
              shockwaveProgress: _animController.value,
              origin: _origin,
            )
          : null,
      child: widget.child,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<ParticleItem> particles;
  final double shockwaveProgress;
  final Offset origin;

  _ParticlePainter({
    required this.particles,
    required this.shockwaveProgress,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw glowing shockwave ring
    if (shockwaveProgress < 0.85) {
      final ringRadius = shockwaveProgress * 180.0;
      final ringOpacity = (1.0 - (shockwaveProgress / 0.85)).clamp(0.0, 1.0);

      final ringPaint = Paint()
        ..color = AppTheme.goldAccent.withOpacity(ringOpacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - shockwaveProgress);

      canvas.drawCircle(origin, ringRadius, ringPaint);
    }

    // 2. Draw each particle
    for (final p in particles) {
      if (p.alpha <= 0.0) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(p.alpha)
        ..style = PaintingStyle.fill;

      if (p.shapeType == 0) {
        // Circle
        canvas.drawCircle(Offset(p.x, p.y), p.size * (0.4 + 0.6 * p.alpha), paint);
      } else if (p.shapeType == 1) {
        // 4-Point Star Sparkle
        _drawStar(canvas, Offset(p.x, p.y), p.size * 1.3 * p.alpha, paint);
      } else {
        // Diamond
        _drawDiamond(canvas, Offset(p.x, p.y), p.size * p.alpha, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - r);
    path.lineTo(center.dx + r, center.dy);
    path.lineTo(center.dx, center.dy + r);
    path.lineTo(center.dx - r, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
