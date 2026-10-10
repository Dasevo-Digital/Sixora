import 'dart:js_interop';

import '../extension.dart';

/// `globalThis.sixoraBridge` from bridge.js: the browser APIs the popup
/// needs, the same for Firefox, Chromium and Safari.
@JS('sixoraBridge')
external Bridge get bridge;

extension type Bridge._(JSObject _) implements JSObject {
  external JSPromise<JSString?> read(String area, String key);
  external JSPromise<JSAny?> write(String area, String key, String? value);

  /// Call right in the click handler: browsers ask only during a gesture.
  external JSPromise<JSBoolean> requestHost(String pattern);
  external JSPromise<JSString?> activeTabUrl();
  external JSPromise<JSBoolean> fill(String code);
  external JSPromise<JSAny?> openTab(String path);
  external String version();
  external String language();
  external bool isBrave();
}

/// `storage.local` or `storage.session`.
class BrowserStore implements Store {
  BrowserStore(this.area);
  final String area;

  @override
  Future<String?> read(String key) async =>
      (await bridge.read(area, key).toDart)?.toDart;

  @override
  Future<void> write(String key, String? value) =>
      bridge.write(area, key, value).toDart;
}
