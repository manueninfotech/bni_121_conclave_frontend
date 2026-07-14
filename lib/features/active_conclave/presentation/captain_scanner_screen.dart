import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/time/server_clock.dart';
import '../data/local_db.dart';
import '../domain/active_conclave_models.dart';
import '../domain/attendance_qr.dart';

/// Captain-facing scanner: point at each member's QR (badge or phone) to mark
/// them present. Every record lands on this device, so the captain's roll is
/// complete and visible with no network.
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

  /// Members marked present during this scanning session, newest last.
  final List<String> _scanned = [];

  /// Guards against the same code being handled twice while the DB write is in
  /// flight — the camera fires detections faster than sqflite commits.
  final Set<String> _inFlight = {};

  String? _lastMessage;
  bool _lastWasError = false;

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
      setState(() {
        if (!_scanned.contains(seat.name)) _scanned.add(seat.name);
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
      _lastMessage = message;
      _lastWasError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan · Table ${round.tableNumber} · Round ${round.roundNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          if (_lastMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: (_lastWasError ? Colors.red : Colors.green)
                  .withValues(alpha: 0.12),
              child: Text(
                _lastMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _lastWasError ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Marked present: ${_scanned.length} of ${round.others.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final name in _scanned)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(name),
                  ),
                if (_scanned.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Point the camera at each member\'s QR code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
    );
  }
}
