import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/openwebui_client.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});
  static const routePath = '/app/settings/webview';
  static const routeName = 'settings_webview';

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  WebViewController? _controller;
  String? _initialUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final client = await ref.read(openWebUIClientProvider.future);
      final base = client.baseUrl ?? '';
      setState(() => _initialUrl = base.isNotEmpty ? '$base/settings' : null);
      final token = await client.token;
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (token != null && token.isNotEmpty) 'Cookie': 'token=$token',
      };
      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.transparent)
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) {
                  return NavigationDecision.navigate;
                },
              ),
            );
      _controller = controller;
      if (_initialUrl != null) {
        await controller.loadRequest(Uri.parse(_initialUrl!), headers: headers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebUI Settings')),
      body:
          _initialUrl == null || _controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _controller!),
    );
  }
}
