import 'dart:math' as math;
import 'package:flutter/material.dart';

class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(controller: _controller, delay: 0.0, key: const Key('dot1')),
            const SizedBox(width: 6),
            _Dot(controller: _controller, delay: 0.15, key: const Key('dot2')),
            const SizedBox(width: 6),
            _Dot(controller: _controller, delay: 0.30, key: const Key('dot3')),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.controller, required this.delay});
  final AnimationController controller;
  final double delay;
  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, math.min(1, delay + 0.7), curve: Curves.easeInOut),
    );
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(curved),
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0).animate(curved),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
