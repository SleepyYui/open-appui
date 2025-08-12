import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/openwebui_client.dart';
import 'login_screen.dart';
import '../../chat/screens/chat_room_screen.dart';

class BaseUrlScreen extends ConsumerStatefulWidget {
  const BaseUrlScreen({super.key});

  static const routePath = '/onboarding/base-url';
  static const routeName = 'base_url';

  @override
  ConsumerState<BaseUrlScreen> createState() => _BaseUrlScreenState();
}

class _BaseUrlScreenState extends ConsumerState<BaseUrlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    final client = await ref.read(openWebUIClientProvider.future);
    final url = _controller.text.trim();
    // ignore: avoid_print
    print('[BaseURL] set url=$url');
    await client.setBaseUrl(url);
    try {
      final ok = await client.verifyBaseUrl();
      if (!mounted) return;
      if (ok) {
        // If already have token, go straight in
        final t = await client.token;
        // ignore: avoid_print
        print(
          '[BaseURL] verification OK, tokenPresent=${t != null && t.isNotEmpty}',
        );
        if (t != null && t.isNotEmpty) {
          context.go(ChatRoomScreen.routePath);
        } else {
          context.go(LoginScreen.routePath);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[BaseURL] verification error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to OpenWebUI'),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter your OpenWebUI base URL',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verify(),
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'https://your-openwebui.example.com',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Base URL is required';
                          }
                          final ok = Uri.tryParse(v.trim())?.hasScheme ?? false;
                          if (!ok)
                            return 'Enter a valid URL incl. scheme (http/https)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _verifying ? null : _verify,
                        icon:
                            _verifying
                                ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.link),
                        label: const Text('Verify and continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
