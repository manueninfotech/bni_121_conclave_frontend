import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/active_conclave/domain/active_conclave_models.dart';

/// Admin-tuned talking cadence (seconds), from `settings/roundTiming`.
class RoundTimingConfig {
  final int bioSeconds;
  final int referralSeconds;
  final int bufferSeconds;

  const RoundTimingConfig({
    required this.bioSeconds,
    required this.referralSeconds,
    required this.bufferSeconds,
  });

  static const fallback = RoundTimingConfig(
    bioSeconds: RoundTiming.defaultBioSeconds,
    referralSeconds: RoundTiming.defaultReferralSeconds,
    bufferSeconds: RoundTiming.defaultBufferSeconds,
  );
}

final _roundTimingDocProvider = StreamProvider<RoundTimingConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('settings')
      .doc('roundTiming')
      .snapshots()
      .map((doc) {
    final d = doc.data();
    int pick(String k, int fb) {
      final v = d?[k];
      return (v is num && v > 0) ? v.toInt() : fb;
    }

    return RoundTimingConfig(
      bioSeconds: pick('bioSeconds', RoundTiming.defaultBioSeconds),
      referralSeconds: pick('referralSeconds', RoundTiming.defaultReferralSeconds),
      bufferSeconds: pick('bufferSeconds', RoundTiming.defaultBufferSeconds),
    );
  });
});

/// Always a usable config: the live settings when available, else the defaults.
final roundTimingConfigProvider = Provider<RoundTimingConfig>((ref) {
  return ref.watch(_roundTimingDocProvider).asData?.value ??
      RoundTimingConfig.fallback;
});
