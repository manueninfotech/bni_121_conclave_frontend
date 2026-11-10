import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/feedback_repository.dart';
import '../round/deck_footer.dart' show roundPanel;
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

// --- Post-conclave feedback (replaces the Google Form) ---------------------

/// "How was the conclave?" — a calm white card that opens the feedback sheet,
/// and a quiet thank-you once it's sent.
class SummaryFeedbackCard extends ConsumerStatefulWidget {
  final String conclaveId;
  const SummaryFeedbackCard({super.key, required this.conclaveId});

  @override
  ConsumerState<SummaryFeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<SummaryFeedbackCard> {
  bool _done = false;
  String get _prefKey => 'feedback_done_${widget.conclaveId}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted && (p.getBool(_prefKey) ?? false)) {
        setState(() => _done = true);
      }
    });
  }

  Future<void> _open() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeedbackSheet(conclaveId: widget.conclaveId),
    );
    if (ok == true) {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, true);
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _done ? null : _open,
        child: Ink(
          padding: const EdgeInsets.all(Gap.md),
          decoration: roundPanel(context),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _done ? CoolIcons.check : CoolIcons.star,
                  size: 20,
                  color: _done
                      ? context.colors.success
                      : context.scheme.onSurface,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _done
                          ? 'Thanks for your feedback'
                          : 'How was the conclave?',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _done
                          ? 'It shapes the next one.'
                          : 'Share 30 seconds of feedback',
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (!_done) Icon(CoolIcons.chevronRight, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  final String conclaveId;
  const _FeedbackSheet({required this.conclaveId});

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  int _rating = 0;
  String? _timing; // 'short' | 'right' | 'long'
  final _referrals = TextEditingController();
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _referrals.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please tap a star rating.')),
        );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .submit(
            widget.conclaveId,
            rating: _rating,
            timing: _timing,
            referrals: int.tryParse(_referrals.text.trim()),
            comment: _comment.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: context.colors.danger,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        top: Gap.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was the conclave?',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Your feedback shapes the next one.',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.lg),

          // Star rating.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? CoolIcons.starFill : CoolIcons.star,
                  color: filled ? Colors.amber : context.scheme.outline,
                  size: 38,
                ),
              );
            }),
          ),
          const SizedBox(height: Gap.md),

          Text(
            'Round timing',
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final opt in const [
                ('short', 'Too short'),
                ('right', 'Just right'),
                ('long', 'Too long'),
              ])
                ChoiceChip(
                  label: Text(opt.$2),
                  selected: _timing == opt.$1,
                  onSelected: (_) => setState(() => _timing = opt.$1),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),

          TextField(
            controller: _referrals,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Referrals / 1-2-1s you got (optional)',
              prefixIcon: Icon(CoolIcons.handshake),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'One thing we should improve (optional)',
            ),
          ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
