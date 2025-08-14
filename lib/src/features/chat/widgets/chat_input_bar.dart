import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings/app_settings.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.onStop,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final VoidCallback? onStop;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enterToSend = ref.watch(appSettingsProvider).enterToSend;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: TextField(
        controller: widget.controller,
        minLines: 1,
        maxLines: enterToSend ? 1 : 6,
        textInputAction:
            enterToSend ? TextInputAction.send : TextInputAction.newline,
        onSubmitted: (_) async {
          if (enterToSend && !widget.isSending) widget.onSend();
        },
        decoration: InputDecoration(
          hintText: 'Message',
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton.filled(
              key: const Key('sendButton'),
              onPressed:
                  widget.isSending ? (widget.onStop ?? () {}) : widget.onSend,
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              icon:
                  widget.isSending
                      ? Semantics(
                        label: 'Model is responding, tap to stop',
                        button: true,
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Material 3 indeterminate spinner; colors derive from theme
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                                semanticsLabel: 'Sending',
                              ),
                              Icon(
                                Icons.stop_rounded,
                                size: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withValues(alpha: 0.90),
                              ),
                            ],
                          ),
                        ),
                      )
                      : const Icon(Icons.send_rounded),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
        ),
      ),
    );
  }
}
