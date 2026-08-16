import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';

/// This member's referrals across every conclave — who they referred, and who
/// referred them.
///
/// Placeholder shell — aggregation across conclaves is wired to the backend in
/// a following step.
class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My referrals')),
      body: const EmptyView(
        icon: Icons.swap_horiz_rounded,
        title: 'Your referral network',
        message: 'Your given and received referrals will appear here.',
      ),
    );
  }
}
