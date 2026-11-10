import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// Max length of a Conclave Specific Ask (matches the server).
const int kSpecificAskMax = 200;

/// "Your ask for this conclave": one line every tablemate sees on your card
/// during the rounds, so anyone who can help knows. Editable until the
/// conclave starts; read-only after.
class SpecificAskCard extends ConsumerWidget {
  final Conclave conclave;
  const SpecificAskCard({super.key, required this.conclave});

  bool get _editable =>
      conclave.effectiveStatus != ConclaveStatus.running &&
      conclave.effectiveStatus != ConclaveStatus.completed &&
      conclave.effectiveStatus != ConclaveStatus.cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ask = conclave.mySpecificAsk?.trim() ?? '';
    final muted = context.scheme.onSurfaceVariant;
    if (ask.isEmpty && !_editable) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: _editable ? () => _edit(context, ref, ask) : null,
        child: Ink(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: context.colors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CoolIcons.megaphone, color: context.scheme.onSurface),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your ask for this conclave',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ask.isEmpty
                          ? 'Tell your tablemates what you are looking for. It shows on your card in every round.'
                          : ask,
                      style: context.text.bodyMedium?.copyWith(
                        color: ask.isEmpty ? muted : context.scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editable) ...[
                const SizedBox(width: Gap.sm),
                Text(
                  ask.isEmpty ? 'Add' : 'Edit',
                  style: context.text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final saved = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AskSheet(initial: current),
    );
    if (saved == null) return;
    try {
      await ref
          .read(conclaveRepositoryProvider)
          .setSpecificAsk(conclave.id, saved);
      ref.invalidate(conclavesStreamProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            showCloseIcon: true,
          ),
        );
    }
  }
}

class _AskSheet extends StatefulWidget {
  final String initial;
  const _AskSheet({required this.initial});

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
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
            'Your ask for this conclave',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'One clear line: who you want to meet or what you need. For example, '
            '"Introductions to hospital purchase managers in Guntur".',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: kSpecificAskMax,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What are you looking for?',
            ),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _c.text.trim()),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
