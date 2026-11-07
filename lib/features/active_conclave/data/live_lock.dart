import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conclaves/data/conclave_repository.dart';
import '../../conclaves/domain/conclave_model.dart';
import 'active_conclave_repository.dart';

/// The conclave whose round is live for this member right now, or null when
/// they are free to roam. This is what the Rapido-style lock holds them on.
///
/// Keyed off the live round ITSELF (activeRoundProvider resolves a seat for
/// them), NOT the conclaves-list `status` field. The list caches `/conclaves`
/// and only re-fetches on resume / every 30s / pull, so keying off it left the
/// lock failing to engage until the member happened to open the Ongoing tab
/// (the list was still showing the conclave as upcoming). The live round comes
/// from the conclave DOCUMENT stream, which flips to running the instant the
/// admin starts it — so the lock now engages immediately, from any screen.
///
/// Only registered, not-finished conclaves are considered (normally one), so at
/// most a handful of live document streams are ever open. `.value` (not asData)
/// keeps the last resolved round through a momentary stream reload — e.g. the
/// resume refetch — so the member isn't briefly unlocked and bounced off and
/// back.
final liveConclaveProvider = Provider<Conclave?>((ref) {
  final all = ref.watch(conclavesStreamProvider).value ?? const <Conclave>[];
  for (final c in all) {
    if (!c.isRegistered) continue;
    if (c.effectiveStatus == ConclaveStatus.completed ||
        c.effectiveStatus == ConclaveStatus.cancelled) {
      continue;
    }
    if (ref.watch(activeRoundProvider(c.id)).value?.round != null) {
      return c;
    }
  }
  return null;
});
