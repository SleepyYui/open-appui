import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Message',
          filled: true,
          fillColor: scheme.surfaceVariant.withOpacity(0.2),
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
            child: IconButton(
              onPressed: isSending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              icon:
                  isSending
                      ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.send_rounded),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
        ),
        onSubmitted: (_) => onSend(),
      ),
    );
  }
}
