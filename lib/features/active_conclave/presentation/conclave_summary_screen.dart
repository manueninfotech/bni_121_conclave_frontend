import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conclave_summary_repository.dart';
import '../data/sync_service.dart';
import '../domain/referral_models.dart';

/// Shown once a conclave is over: what the user did, and — crucially — whether
/// it made it off their phone.
///
/// The sync column is the point of this screen. At a venue with no working
/// internet, "did my day survive?" is the question the user actually has, and
/// they must be able to answer it without trusting us.
class ConclaveSummaryScreen extends ConsumerWidget {
  final String conclaveId;

  const ConclaveSummaryScreen({super.key, required this.conclaveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(conclaveSummaryProvider(conclaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conclave Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow(conclaveId);
              ref.invalidate(conclaveSummaryProvider(conclaveId));
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SyncBanner(summary: summary),
            const SizedBox(height: 16),
            _AttendanceSection(summary: summary),
            const SizedBox(height: 24),
            _ReferralsSection(referrals: summary.referrals),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final ConclaveSummary summary;

  const _SyncBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ok = summary.fullySynced;
    final color = ok ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.cloud_done : Icons.cloud_upload, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok
                  ? 'Everything you recorded has been saved to the server.'
                  : '${summary.pendingSyncCount} record(s) are still on this phone and '
                      'have not reached the server. They will upload automatically '
                      'when you have a connection — keep the app installed.',
              style: TextStyle(color: color.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  final ConclaveSummary summary;

  const _AttendanceSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance — ${summary.roundsAttended} round(s) attended',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (summary.attendance.isEmpty)
          const Text('No attendance was recorded for you.',
              style: TextStyle(color: Colors.grey))
        else
          for (final a in summary.attendance)
            ListTile(
              dense: true,
              leading: Icon(
                a.isPresent ? Icons.check_circle : Icons.cancel,
                color: a.isPresent ? Colors.green : Colors.red,
              ),
              title: Text('Round ${a.roundNumber}'),
              subtitle: Text(a.isPresent ? 'Present' : 'Absent'),
              trailing: _SyncChip(synced: a.synced),
            ),
      ],
    );
  }
}

class _ReferralsSection extends StatelessWidget {
  final ReferralSummary referrals;

  const _ReferralsSection({required this.referrals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Referrals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Given: ${referrals.givenCount}')),
            Chip(label: Text('Received: ${referrals.receivedCount}')),
            Chip(
              label: Text('Mutual: ${referrals.mutualCount}'),
              backgroundColor: Colors.indigo.withValues(alpha: 0.12),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('Given', style: TextStyle(fontWeight: FontWeight.bold)),
        if (referrals.given.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('You gave no referrals.', style: TextStyle(color: Colors.grey)),
          )
        else
          for (final r in referrals.given)
            ListTile(
              dense: true,
              leading: const Icon(Icons.call_made, color: Colors.blue),
              title: Text(
                r.otherName.isNotEmpty ? r.otherName : 'Unknown participant',
              ),
              subtitle: Text(
                '${r.otherBusinessName}${r.otherBusinessName.isNotEmpty ? ' · ' : ''}'
                'Round ${r.roundNumber}'
                '${r.notes.isNotEmpty ? ' · ${r.notes}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (referrals.isMutualWith(r.toUserId))
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Chip(label: Text('Mutual')),
                    ),
                  _SyncChip(synced: r.synced),
                ],
              ),
            ),

        const SizedBox(height: 16),
        const Text('Received', style: TextStyle(fontWeight: FontWeight.bold)),
        if (referrals.received.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No referrals received yet. Referrals given to you are created on '
              'the other person\'s phone, so they appear here only after both '
              'devices have synced.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          for (final r in referrals.received)
            ListTile(
              dense: true,
              leading: const Icon(Icons.call_received, color: Colors.green),
              title: Text(r.otherName.isNotEmpty ? r.otherName : r.fromUserId),
              subtitle: Text(
                '${r.otherBusinessName}${r.otherBusinessName.isNotEmpty ? ' · ' : ''}'
                'Round ${r.roundNumber}'
                '${r.notes.isNotEmpty ? ' · ${r.notes}' : ''}',
              ),
              trailing: referrals.isMutualWith(r.fromUserId)
                  ? const Chip(label: Text('Mutual'))
                  : null,
            ),
      ],
    );
  }
}

class _SyncChip extends StatelessWidget {
  final bool synced;

  const _SyncChip({required this.synced});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(
        synced ? 'Synced' : 'Pending',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor:
          (synced ? Colors.green : Colors.orange).withValues(alpha: 0.12),
    );
  }
}
