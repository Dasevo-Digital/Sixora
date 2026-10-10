import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';

/// Registers nothing: no global shortcuts on Linux (see pubspec.yaml).
class HotkeyManagerLinux extends HotKeyManagerPlatform {
  static void registerWith() {
    HotKeyManagerPlatform.instance = HotkeyManagerLinux();
  }

  @override
  Future<String?> getPlatformVersion() async => null;

  @override
  Stream<Map<Object?, Object?>> get onKeyEventReceiver => const Stream.empty();

  @override
  Future<void> register(HotKey hotKey) async {}

  @override
  Future<void> unregister(HotKey hotKey) async {}

  @override
  Future<void> unregisterAll() async {}
}
