import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../data/one_to_ones_repository.dart';

/// Opens the "request a 1-2-1" sheet. Resolves true if a request was sent.
Future<bool?> showProposeOneToOne(
  BuildContext context, {
  required String toUserId,
  required String toName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProposeSheet(toUserId: toUserId, toName: toName),
  );
}

class _ProposeSheet extends ConsumerStatefulWidget {
  final String toUserId;
  final String toName;
  const _ProposeSheet({required this.toUserId, required this.toName});

  @override
  ConsumerState<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends ConsumerState<_ProposeSheet> {
  final _location = TextEditingController();
  final _note = TextEditingController();
  DateTime? _when;
  bool _sending = false;

  @override
  void dispose() {
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    if (_when == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(oneToOnesRepositoryProvider).propose(
            toUserId: widget.toUserId,
            proposedAt: _when!,
            location: _location.text.trim(),
            note: _note.text.trim(),
          );
      ref.invalidate(myOneToOnesProvider);
      if (mounted) Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('1-2-1 requested with ${widget.toName}.')),
      );
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Request a 1-2-1',
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'with ${widget.toName}',
            style: context.text.bodyMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.lg),

          // Date & time
          InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: _pickWhen,
            child: InputDecorator(
              isEmpty: _when == null,
              decoration: const InputDecoration(
                labelText: 'Date & time',
                prefixIcon: Icon(Icons.event_rounded),
                suffixIcon: Icon(Icons.expand_more_rounded),
              ),
              child: _when == null
                  ? null
                  : Text(DateFormat('EEE, MMM d · h:mm a').format(_when!)),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Where (optional)',
              hintText: 'e.g. Café Coffee Day, Brodipet',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_when == null || _sending) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send request'),
            ),
          ),
        ],
      ),
    );
  }
}
