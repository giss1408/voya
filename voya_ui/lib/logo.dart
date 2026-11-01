import 'package:flutter/material.dart';

import 'theme.dart';

/// The Voya mark: a route from an origin dot to a destination ring on an
/// ochre tile. Mirrors `brand/voya-mark.svg` (96-unit grid).
class VoyaMark extends StatelessWidget {
  final double size;
  const VoyaMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Voya',
        image: true,
        child: ExcludeSemantics(
          child: CustomPaint(size: Size.square(size), painter: _MarkPainter()),
        ),
      );
}

/// Mark plus the "Voya" wordmark, for headers and the sign-in screen.
class VoyaLogo extends StatelessWidget {
  final double markSize;
  const VoyaLogo({super.key, this.markSize = 32});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoyaMark(size: markSize),
          const SizedBox(width: Space.sm + 2),
          Text(
            'Voya',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: markSize * 0.65,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(24 * k)),
      Paint()..color = VoyaColors.ochre,
    );
    final route = Path()
      ..moveTo(28 * k, 68 * k)
      ..cubicTo(28 * k, 44 * k, 68 * k, 52 * k, 68 * k, 30 * k);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * k
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(28 * k, 68 * k), 7 * k, white);
    canvas.drawCircle(Offset(68 * k, 28 * k), 9 * k, white);
    canvas.drawCircle(
        Offset(68 * k, 28 * k), 3.5 * k, Paint()..color = VoyaColors.ochre);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
