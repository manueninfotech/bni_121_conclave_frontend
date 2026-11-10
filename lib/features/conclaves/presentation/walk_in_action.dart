import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'specific_ask_card.dart' show kSpecificAskMax;
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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
    final ask = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WalkInSheet(),
    );
    if (ask == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(conclaveRepositoryProvider)
          .requestWalkIn(widget.conclave.id, specificAsk: ask);
      ref.invalidate(conclavesStreamProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            showCloseIcon: true,
          ),
        );
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
        child: Row(
          children: [
            Icon(CoolIcons.hourglass, color: context.scheme.onSurface),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for the region admin',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Pay at the desk if you have not yet. You will be seated from the next round.',
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(CoolIcons.userPlusCorner),
        label: const Text('Join as walk-in'),
      ),
    );
  }
}

/// The walk-in explainer plus an optional Conclave Specific Ask. Pops the ask
/// text ("" when left empty) on "Send request", null when dismissed.
class _WalkInSheet extends StatefulWidget {
  const _WalkInSheet();

  @override
  State<_WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<_WalkInSheet> {
  final _askCtrl = TextEditingController();

  @override
  void dispose() {
    _askCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.xl,
        0,
        Gap.xl,
        MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join as a walk-in',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Gap.sm),
          for (final line in const [
            (
              CoolIcons.banknote,
              'Pay the registration fee at the desk. There is no payment in the app.',
            ),
            (CoolIcons.shieldCheck, 'The region admin approves your request.'),
            (
              CoolIcons.armchair,
              "You're seated from the next round. The app tells you your table.",
            ),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    line.$1,
                    size: 20,
                    color: context.scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(line.$2, style: context.text.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _askCtrl,
            maxLength: kSpecificAskMax,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your ask for this conclave (optional)',
              hintText: 'Who you want to meet or what you need',
            ),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _askCtrl.text.trim()),
              child: const Text('Send request'),
            ),
          ),
        ],
      ),
    );
  }
}
