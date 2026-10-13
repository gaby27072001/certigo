// Fixture for .github/sast/rules/dart-security.yaml — WebView rules (preventive: Certigo
// ships no WebView today; these rules make adding one a reviewed decision).

void webview(WebViewController controller, InAppWebViewController inApp, String url) {
  // ruleid: dart-webview-javascript-enabled
  controller.setJavaScriptMode(JavaScriptMode.unrestricted);

  // ok: dart-webview-javascript-enabled
  controller.setJavaScriptMode(JavaScriptMode.disabled);

  // ruleid: dart-webview-javascript-enabled
  final Widget legacy = WebView(javascriptMode: JavascriptMode.unrestricted);

  // ruleid: dart-webview-javascript-enabled, dart-webview-file-access
  final InAppWebViewSettings settings = InAppWebViewSettings(javaScriptEnabled: true, allowFileAccessFromFileURLs: true);

  // ok: dart-webview-javascript-enabled, dart-webview-file-access
  final InAppWebViewSettings locked = InAppWebViewSettings(javaScriptEnabled: false, allowFileAccessFromFileURLs: false);

  // ruleid: dart-webview-javascript-bridge
  controller.addJavaScriptChannel('Bridge', onMessageReceived: (JavaScriptMessage message) {});

  // ruleid: dart-webview-javascript-bridge
  inApp.addJavaScriptHandler(handlerName: 'bridge', callback: (List<dynamic> args) {});

  // ruleid: dart-webview-javascript-bridge
  final Widget channels = WebView(javascriptChannels: <JavascriptChannel>{bridge});

  // ok: dart-webview-javascript-bridge
  controller.removeJavaScriptChannel('Bridge');

  // ruleid: dart-webview-file-access
  final InAppWebViewSettings universal = InAppWebViewSettings(allowUniversalAccessFromFileURLs: true);

  // ruleid: dart-webview-file-access
  final InAppWebViewSettings mixed = InAppWebViewSettings(mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW);

  // ruleid: dart-webview-file-access
  androidController.setAllowFileAccess(true);

  // ruleid: dart-webview-dynamic-content
  controller.loadRequest(Uri.parse(url));

  // ruleid: dart-webview-dynamic-content
  controller.loadHtmlString(url);

  // ok: dart-webview-dynamic-content
  controller.loadRequest(Uri.parse('https://certigo.example/help'));

  // ok: dart-webview-dynamic-content
  controller.loadHtmlString('<p>Aide</p>');
}
