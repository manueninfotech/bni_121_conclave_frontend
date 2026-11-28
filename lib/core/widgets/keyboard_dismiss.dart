import 'package:flutter/widgets.dart';

/// Closes the keyboard when the user taps anywhere outside the focused field,
/// or drags any scrollable (lists, sheets such as the country picker, pages).
/// Sits above the Navigator, so it covers every screen and bottom sheet.
///
/// A passive [Listener], not a GestureDetector: it never joins the gesture
/// arena, so it can't steal taps, scrolls, or the iOS edge swipe-back.
class KeyboardDismissOnTap extends StatefulWidget {
  final Widget child;
  const KeyboardDismissOnTap({super.key, required this.child});

  @override
  State<KeyboardDismissOnTap> createState() => _KeyboardDismissOnTapState();
}

class _KeyboardDismissOnTapState extends State<KeyboardDismissOnTap> {
  Offset? _down;

  void _onUp(PointerUpEvent e) {
    final start = _down;
    _down = null;
    if (start == null || (e.position - start).distance > 12) return; // a drag
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return;
    final box = focus.context!.findRenderObject();
    if (box is RenderBox && box.attached) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(e.position)) return; // tapped inside the field
    }
    focus.unfocus();
  }

  /// A finger drag on any scrollable closes the keyboard. Scrolls the app
  /// makes itself (bringing a field into view) carry no drag details, so they
  /// leave the keyboard alone.
  bool _onScroll(ScrollUpdateNotification n) {
    if (n.dragDetails == null) return false;
    final focus = FocusManager.instance.primaryFocus;
    final field = focus?.context;
    if (focus == null || field == null) return false;
    // Scrolling inside the focused field itself (a long note) keeps it open.
    var inside = false;
    n.context?.visitAncestorElements((e) {
      if (e == field) {
        inside = true;
        return false;
      }
      return true;
    });
    if (!inside) focus.unfocus();
    return false; // let others see it too
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _down = e.position,
          onPointerUp: _onUp,
          onPointerCancel: (_) => _down = null,
          child: widget.child,
        ),
      );
}
