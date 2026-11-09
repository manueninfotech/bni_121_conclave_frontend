import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import 'round_avatar.dart';
import 'round_timer.dart';

/// Who this member has referred / written a note for this round — the live
/// state the referral sheet renders from.
typedef ReferralSheetState = ({Set<String> referred, Set<String> noted});

/// One-tap referrals: a sheet of everyone at the table, so a member can pass a
/// lead without swiping to find the right card. Only opened during the referral
/// slot (the caller gates the button to it).
///
/// The sheet SUBSCRIBES to [state] rather than copying it when it opens, so a
/// referral or a saved note shows up immediately (Refer → Add note → Edit note)
/// without closing and reopening it.
void showReferralSheet(
  BuildContext context, {
  required List<TableSeat> tablemates,
  required ValueListenable<ReferralSheetState> state,
  required void Function(TableSeat) onRefer,
  required void Function(TableSeat) onNote,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return ValueListenableBuilder<ReferralSheetState>(
        valueListenable: state,
        builder: (ctx, s, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Give a referral',
                      style: ctx.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Pass a lead to someone at your table — then add the contact as a note.',
                    style: ctx.text.bodySmall
                        ?.copyWith(color: ctx.scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.md),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tablemates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                      itemBuilder: (ctx, i) {
                        final seat = tablemates[i];
                        return ReferralSheetRow(
                          seat: seat,
                          referred: s.referred.contains(seat.userId),
                          hasNote: s.noted.contains(seat.userId),
                          onRefer: () => onRefer(seat),
                          onNote: () => onNote(seat),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// A row in the one-tap referral sheet.
class ReferralSheetRow extends StatelessWidget {
  final TableSeat seat;
  final bool referred;
  final bool hasNote;
  final VoidCallback onRefer;
  final VoidCallback onNote;
  const ReferralSheetRow({
    super.key,
    required this.seat,
    required this.referred,
    required this.hasNote,
    required this.onRefer,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.md, Gap.sm),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _sheetAvatar(context, seat),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seat.name,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (seat.category.isNotEmpty)
                  Text(seat.category,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          if (referred) ...[
            Icon(Icons.check_circle, color: context.scheme.primary, size: 20),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: onNote,
              icon: Icon(hasNote ? Icons.edit_note : Icons.sticky_note_2_outlined,
                  size: 16),
              label: Text(hasNote ? 'Edit note' : 'Add note'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kDeckBottom,
                side: const BorderSide(color: kDeckBottom),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ] else
            FilledButton(
              onPressed: onRefer,
              style: FilledButton.styleFrom(
                backgroundColor: kDeckBottom,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refer'),
            ),
        ],
      ),
    );
  }
}

Widget _sheetAvatar(BuildContext context, TableSeat seat) {
  return Container(
    width: 46,
    height: 46,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.scheme.surfaceContainerHigh,
    ),
    alignment: Alignment.center,
    child: seat.photoUrl != null
        ? Image.network(seat.photoUrl!,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => roundInitialAvatarText(context, seat))
        : roundInitialAvatarText(context, seat),
  );
}
