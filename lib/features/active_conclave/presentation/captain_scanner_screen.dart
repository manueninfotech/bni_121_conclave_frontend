import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/server_clock.dart';
import '../data/local_db.dart';
import '../domain/active_conclave_models.dart';
import '../domain/attendance_qr.dart';

/// Captain-facing scanner: point at each member's QR (badge or phone) to mark
/// them present. Every record lands on this device, so the captain's roll is
/// complete and visible with no network.
///
/// The camera fills the screen because that is the task — everything else is
/// overlay. Feedback has to be readable at arm's length while the phone is
/// moving, so it is large, high-contrast, and confirmed by haptics: at a noisy
/// venue you feel the scan land before you read it.
class CaptainScannerScreen extends ConsumerStatefulWidget {
  final ActiveRound round;

  const CaptainScannerScreen({super.key, required this.round});

  @override
  ConsumerState<CaptainScannerScreen> createState() => _CaptainScannerScreenState();
}

class _CaptainScannerScreenState extends ConsumerState<CaptainScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Members marked present in this session, newest first.
  final List<String> _scanned = [];

  /// Guards against the same code being handled twice while the DB write is in
  /// flight — the camera fires detections faster than sqflite commits.
  final Set<String> _inFlight = {};

  String? _message;
  bool _isError = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _inFlight.contains(raw)) return;
    _inFlight.add(raw);

    try {
      final outcome = validateScan(
        raw: raw,
        round: widget.round,
        // Server-corrected: a drifted phone must not keep scanning people in
        // after the round has actually closed.
        now: ref.read(serverClockProvider).now(),
      );

      if (!outcome.isAccepted) {
        HapticFeedback.heavyImpact();
        _report(scanMessage(outcome), isError: true);
        return;
      }

      final seat = outcome.seat!;
      await ref.read(localDbProvider).markAttendance(
            conclaveId: widget.round.conclaveId,
            roundNumber: widget.round.roundNumber,
            tableNumber: widget.round.tableNumber,
            userId: seat.userId,
            isPresent: true,
            markedBy: widget.round.currentUserId,
          );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _scanned.remove(seat.name);
        _scanned.insert(0, seat.name);
      });
      _report(scanMessage(outcome), isError: false);
    } finally {
      // Allow a re-scan of the same person later (e.g. to correct a mistake),
      // but not a double-fire from one presentation of the code.
      await Future<void>.delayed(const Duration(seconds: 2));
      _inFlight.remove(raw);
    }
  }

  void _report(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _isError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final total = round.others.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Darken everything but the aiming window, so the eye knows where to
          // put the badge without being told.
          const _ScannerMask(),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  round: round,
                  torch: _torch,
                  onTorch: () {
                    _controller.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                ),
                const Spacer(),
                if (_message != null)
                  _Feedback(message: _message!, isError: _isError),
                const SizedBox(height: Gap.lg),
                _Progress(scanned: _scanned, total: total),
                const SizedBox(height: Gap.lg),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        _scanned.isEmpty ? 'Close' : 'Done · ${_scanned.length} marked',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A dimming mask with a clear aiming window punched out of it.
class _ScannerMask extends StatelessWidget {
  const _ScannerMask();

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).width * 0.68;

    return Stack(
      alignment: Alignment.center,
      children: [
        // ColorFiltered + blend punches a real hole rather than faking one with
        // four rectangles that never quite line up.
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.62),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
              borderRadius: BorderRadius.circular(Radii.xl),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final ActiveRound round;
  final bool torch;
  final VoidCallback onTorch;

  const _TopBar({required this.round, required this.torch, required this.onTorch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            tooltip: 'Close scanner',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Scan members',
                  style: context.text.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Table ${round.tableNumber} · Round ${round.roundNumber}',
                  style: context.text.labelSmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTorch,
            // A venue hall is dim and a badge is often in shadow — the torch is
            // a primary control here, not a nicety.
            icon: Icon(torch ? Icons.flashlight_on : Icons.flashlight_off),
            color: torch ? Colors.amber : Colors.white,
            tooltip: torch ? 'Turn torch off' : 'Turn torch on',
          ),
        ],
      ),
    );
  }
}

/// Scan feedback. Large, high contrast, and legible while the phone is moving.
class _Feedback extends StatelessWidget {
  final String message;
  final bool isError;

  const _Feedback({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(message),
        tween: Tween(begin: 0, end: 1),
        duration: Motion.normal,
        curve: Motion.spring,
        builder: (context, t, child) => Transform.scale(
          scale: 0.94 + (0.06 * t),
          child: Opacity(opacity: t.clamp(0, 1), child: child),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: isError ? c.dangerContainer : c.successContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: isError ? c.onDangerContainer : c.onSuccessContainer,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  message,
                  style: context.text.titleSmall?.copyWith(
                    color: isError ? c.onDangerContainer : c.onSuccessContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final List<String> scanned;
  final int total;

  const _Progress({required this.scanned, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.xl),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${scanned.length} of $total marked',
                style: context.text.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (scanned.length == total && total > 0)
                Text(
                  'All present',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.colors.success),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : scanned.length / total),
              duration: Motion.normal,
              curve: Motion.curve,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                color: context.colors.success,
              ),
            ),
          ),
          if (scanned.isEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(
              'Point the camera at a member\'s QR code.',
              style: context.text.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ] else ...[
            const SizedBox(height: Gap.md),
            // Newest first: the confirmation you're looking for is the one you
            // just scanned.
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final name in scanned.take(6))
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.xs),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 13, color: context.colors.success),
                        const SizedBox(width: Gap.xs),
                        Text(
                          name,
                          style: context.text.labelSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
