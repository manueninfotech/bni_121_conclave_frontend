import 'package:flutter/material.dart';

/// Formerly pull-to-refresh. By the client's direction there is no
/// pull-to-refresh: dragging down at the top of a screen does nothing — the
/// header stays put, with no spinner, bounce or stretch. Data still refreshes
/// on its own (every cached screen refetches in the background).
///
/// Kept as a wrapper so screens didn't need restructuring; [onRefresh] is no
/// longer triggered by a gesture.
class AppRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefresh({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // Content stops dead at its edges on both platforms.
      behavior: ScrollConfiguration.of(context).copyWith(
        physics: const ClampingScrollPhysics(),
        overscroll: false,
      ),
      child: child,
    );
  }
}
