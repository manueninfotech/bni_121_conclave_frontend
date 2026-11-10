import 'package:flutter/widgets.dart';

/// Closes the keyboard when the user taps anywhere outside the focused field.
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

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => _down = e.position,
    onPointerUp: _onUp,
    onPointerCancel: (_) => _down = null,
    child: widget.child,
  );
}
