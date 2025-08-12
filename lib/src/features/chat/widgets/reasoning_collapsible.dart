import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ReasoningCollapsible extends StatefulWidget {
  const ReasoningCollapsible({
    super.key,
    required this.reasoning,
    this.done = false,
    this.durationSeconds,
  });

  final String reasoning;
  final bool done;
  final int? durationSeconds;

  @override
  State<ReasoningCollapsible> createState() => _ReasoningCollapsibleState();
}

class _ReasoningCollapsibleState extends State<ReasoningCollapsible> {
  bool _open = false;

  String _summaryText() {
    if (!widget.done) return 'Thinking...';
    final s = widget.durationSeconds ?? 0;
    if (s < 1) return 'Thought for less than a second';
    if (s < 60) return 'Thought for $s seconds';
    final m = (s / 60).floor();
    return m == 1 ? 'Thought for 1 minute' : 'Thought for $m minutes';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: scheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                _summaryText(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child:
              _open
                  ? Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MarkdownBody(data: widget.reasoning),
                      ),
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
