import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLine extends StatelessWidget {
  const ShimmerLine({
    super.key,
    this.height = 12,
    this.width = double.infinity,
    this.radius = 6,
  });
  final double height;
  final double width;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
    final highlight = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
