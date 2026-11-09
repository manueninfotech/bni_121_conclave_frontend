import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';

/// "Join as walk-in" for a conclave that's already running, and the calm
/// waiting state after asking. Payment is taken by the region admin at the
/// desk, never in the app; once approved the member is seated from the next
/// round and the normal "Join active round" flow takes over.
class WalkInAction extends ConsumerStatefulWidget {
  final Conclave conclave;
  const WalkInAction({super.key, required this.conclave});

  @override
  ConsumerState<WalkInAction> createState() => _WalkInActionState();
}

class _WalkInActionState extends ConsumerState<WalkInAction> {
  bool _sending = false;

  Future<void> _ask() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join as a walk-in',
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.sm),
            for (final line in const [
              (Icons.payments_outlined, 'Pay the registration fee at the desk. There is no payment in the app.'),
              (Icons.verified_user_outlined, 'The region admin approves your request.'),
              (Icons.table_restaurant_outlined, "You're seated from the next round. The app tells you your table."),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(line.$1, size: 20, color: context.scheme.onSurfaceVariant),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(line.$2, style: context.text.bodyMedium)),
                ]),
              ),
            const SizedBox(height: Gap.lg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send request'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(conclaveRepositoryProvider).requestWalkIn(widget.conclave.id);
      ref.invalidate(conclavesStreamProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          showCloseIcon: true,
        ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conclave.walkInStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(children: [
          Icon(Icons.hourglass_top_rounded, color: context.scheme.onSurface),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Waiting for the region admin',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  'Pay at the desk if you have not yet. You will be seated from the next round.',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ]),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _sending ? null : _ask,
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Join as walk-in'),
      ),
    );
  }
}
