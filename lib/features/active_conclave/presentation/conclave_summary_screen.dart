import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/conclave_summary_repository.dart';
import '../data/sync_service.dart';
import '../domain/referral_models.dart';

/// After the conclave: what you did, and — the point of the screen — whether it
/// actually made it off your phone.
///
/// At a venue with no working internet, "did my day survive?" is the question
/// people genuinely have. They should be able to answer it themselves rather
/// than trust us, so the sync state leads.
class ConclaveSummaryScreen extends ConsumerWidget {
  final String conclaveId;

  const ConclaveSummaryScreen({super.key, required this.conclaveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(conclaveSummaryProvider(conclaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync now',
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow(conclaveId);
              ref.invalidate(conclaveSummaryProvider(conclaveId));
            },
          ),
        ],
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your summary.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(conclaveSummaryProvider(conclaveId)),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncServiceProvider).syncNow(conclaveId);
            ref.invalidate(conclaveSummaryProvider(conclaveId));
          },
          child: ContentWidth(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.pageInsets,
              children: [
                FadeSlideIn(index: 0, child: _SyncBanner(summary: s)),
                const SizedBox(height: Gap.lg),
                FadeSlideIn(index: 1, child: _Scoreboard(summary: s)),
                const SizedBox(height: Gap.xl),
                FadeSlideIn(index: 2, child: _Attendance(summary: s)),
                const SizedBox(height: Gap.xl),
                FadeSlideIn(index: 3, child: _Referrals(referrals: s.referrals)),
              ],
            ),
          ),
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
    final c = context.colors;
    final ok = summary.fullySynced;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: ok ? c.successContainer : c.warningContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
            color: ok ? c.onSuccessContainer : c.onWarningContainer,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Everything is saved' : '${summary.pendingSyncCount} still uploading',
                  style: context.text.titleSmall?.copyWith(
                    color: ok ? c.onSuccessContainer : c.onWarningContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  ok
                      ? 'Your attendance and referrals are on the server.'
                      : 'They will upload automatically when you have a connection. '
                          'Keep the app installed until then.',
                  style: context.text.bodySmall?.copyWith(
                    color: ok ? c.onSuccessContainer : c.onWarningContainer,
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

/// The three numbers people actually want, at a glance.
class _Scoreboard extends StatelessWidget {
  final ConclaveSummary summary;
  const _Scoreboard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final r = summary.referrals;

    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: '${r.givenCount}',
            label: 'Given',
            icon: Icons.call_made_rounded,
            tone: StatusTone.info,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _Stat(
            value: '${r.receivedCount}',
            label: 'Received',
            icon: Icons.call_received_rounded,
            tone: StatusTone.success,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _Stat(
            value: '${r.mutualCount}',
            label: 'Mutual',
            icon: Icons.swap_horiz_rounded,
            tone: StatusTone.neutral,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final StatusTone tone;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = switch (tone) {
      StatusTone.success => c.success,
      StatusTone.info => c.info,
      _ => context.scheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg, horizontal: Gap.sm),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(height: Gap.sm),
          Text(
            value,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Attendance extends StatelessWidget {
  final ConclaveSummary summary;
  const _Attendance({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Attendance',
          trailing: '${summary.roundsAttended} round(s) attended',
        ),
        const SizedBox(height: Gap.sm),
        if (summary.attendance.isEmpty)
          _Muted('No attendance was recorded for you.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < summary.attendance.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.hairline),
                  _AttendanceRow(a: summary.attendance[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final RoundAttendance a;
  const _AttendanceRow({required this.a});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: a.isPresent ? c.successContainer : c.dangerContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              a.isPresent ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: a.isPresent ? c.onSuccessContainer : c.onDangerContainer,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Round ${a.roundNumber}', style: context.text.titleSmall),
                Text(
                  a.isPresent ? 'Present' : 'Absent',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _SyncDot(synced: a.synced),
        ],
      ),
    );
  }
}

class _Referrals extends StatelessWidget {
  final ReferralSummary referrals;
  const _Referrals({required this.referrals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Referrals you gave'),
        const SizedBox(height: Gap.sm),
        if (referrals.given.isEmpty)
          _Muted('You gave no referrals.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < referrals.given.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.hairline),
                  _ReferralRow(
                    r: referrals.given[i],
                    mutual: referrals.isMutualWith(referrals.given[i].toUserId),
                    outgoing: true,
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: Gap.xl),
        const _SectionTitle('Referrals you received'),
        const SizedBox(height: Gap.sm),
        if (referrals.received.isEmpty)
          _Muted(
            'None yet. A referral given to you is created on the other person\'s '
            'phone, so it appears here only once both devices have synced.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < referrals.received.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.hairline),
                  _ReferralRow(
                    r: referrals.received[i],
                    mutual: referrals.isMutualWith(referrals.received[i].fromUserId),
                    outgoing: false,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final Referral r;
  final bool mutual;
  final bool outgoing;

  const _ReferralRow({
    required this.r,
    required this.mutual,
    required this.outgoing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = r.otherName.isNotEmpty ? r.otherName : 'Unknown participant';

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: outgoing ? c.infoContainer : c.successContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
              size: 15,
              color: outgoing ? c.onInfoContainer : c.onSuccessContainer,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: context.text.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mutual) ...[
                      const SizedBox(width: Gap.sm),
                      Tooltip(
                        message: 'You referred each other',
                        child: Icon(Icons.swap_horiz_rounded,
                            size: 15, color: context.scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                Text(
                  [
                    if (r.otherBusinessName.isNotEmpty) r.otherBusinessName,
                    'Round ${r.roundNumber}',
                  ].join(' · '),
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                if (r.notes.isNotEmpty) ...[
                  const SizedBox(height: Gap.sm),
                  Container(
                    padding: const EdgeInsets.all(Gap.sm),
                    decoration: BoxDecoration(
                      color: context.scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(r.notes, style: context.text.bodySmall),
                  ),
                ],
              ],
            ),
          ),
          if (outgoing) ...[
            const SizedBox(width: Gap.sm),
            _SyncDot(synced: r.synced),
          ],
        ],
      ),
    );
  }
}

/// A dot, not a chip. Sync state is per-row detail — the headline already says
/// whether anything is outstanding, so this only needs to answer "which one?".
class _SyncDot extends StatelessWidget {
  final bool synced;
  const _SyncDot({required this.synced});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Tooltip(
      message: synced ? 'Saved to the server' : 'Waiting to upload',
      child: Semantics(
        label: synced ? 'Saved' : 'Waiting to upload',
        child: Icon(
          synced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
          size: 16,
          color: synced ? c.success : c.warning,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: context.text.labelSmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Muted extends StatelessWidget {
  final String text;
  const _Muted(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Text(
        text,
        style: context.text.bodySmall
            ?.copyWith(color: context.scheme.onSurfaceVariant),
      ),
    );
  }
}
