import 'package:flutter/services.dart';

/// Bridge to the host activity for things the overlay cannot do from Dart.
///
/// Registered on both Flutter engines by MainActivity: the main one at startup,
/// and the overlay's cached engine via [attachOverlayBridge] once the overlay
/// exists. Without that second registration the overlay isolate has no handler
/// on this channel and every call throws MissingPluginException.
class AppControl {
  AppControl._();

  static const MethodChannel _channel = MethodChannel('njd/app_control');

  /// Register the channel on the overlay's engine. Call from the main isolate
  /// *after* showing the overlay — the engine does not exist before that.
  static Future<bool> attachOverlayBridge() async {
    try {
      return await _channel.invokeMethod<bool>('attachOverlayBridge') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Reopen the app when only the floating clock is on screen. Permitted while
  /// backgrounded because the app holds the overlay permission.
  static Future<bool> bringAppToFront() async {
    try {
      return await _channel.invokeMethod<bool>('bringAppToFront') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
