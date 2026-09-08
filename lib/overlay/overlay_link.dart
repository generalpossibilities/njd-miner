/// Messages passed between the main isolate and the overlay isolate via
/// `FlutterOverlayWindow.shareData` / `overlayListener`.
///
/// Only one miner may run at a time. The rule: **when the overlay is showing,
/// the overlay owns mining** (it survives the main app being backgrounded).
/// The overlay announces itself; the main app yields.
library;

class OverlayMsg {
  OverlayMsg._();

  // overlay → main
  static const String overlayMining =
      'overlay_mining'; // {taps, phase, balance}
  static const String overlayDisplayOnly = 'overlay_display_only';
  static const String overlayTap =
      'overlay_tap'; // {x, y} — forward to main miner
  static const String overlayClosed = 'overlay_closed';

  // main → overlay
  static const String mainYielded =
      'main_yielded'; // main stopped its miner, overlay may start
  static const String mainResumed = 'main_resumed'; // overlay should stop

  static Map<String, Object?> of(String type, [Map<String, Object?>? data]) => {
    'type': type,
    if (data != null) ...data,
  };
}
