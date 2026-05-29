import 'dart:math';
import 'package:flutter/material.dart';

class DonutPainter extends CustomPainter {
  final double percentage; // 0.0 - 1.0
  final Color color;

  DonutPainter({
    required this.percentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;
    final strokeW = 6.0;

    // Track background
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = Colors.grey.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Arc progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percentage,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) =>
      old.percentage != percentage || old.color != color;
}

class DonutStatusBadge extends StatefulWidget {
  final double percentage;
  final Color color;
  final String centerText;

  const DonutStatusBadge({
    Key? key,
    required this.percentage,
    required this.color,
    required this.centerText,
  }) : super(key: key);

  @override
  State<DonutStatusBadge> createState() => _DonutStatusBadgeState();
}

class _DonutStatusBadgeState extends State<DonutStatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Create a pulse animation: 1.0 -> 1.25 -> 1.0
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _triggerPulse,
      onTap: _triggerPulse, // Trigger pulse on single tap too for extra responsiveness
      child: ScaleTransition(
        scale: _animation,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(50, 50),
                painter: DonutPainter(
                  percentage: widget.percentage,
                  color: widget.color,
                ),
              ),
              Text(
                widget.centerText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
