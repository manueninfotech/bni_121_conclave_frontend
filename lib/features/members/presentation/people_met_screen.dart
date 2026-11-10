import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/people_met_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// Everyone you shared a table with at a conclave, across all its rounds — the
/// networking payoff, captured so it survives the day.
class PeopleMetScreen extends ConsumerWidget {
  final String conclaveId;
  const PeopleMetScreen({super.key, required this.conclaveId});

  Future<void> _save(BuildContext context, MetPerson p) async {
    final contact = Contact(
      name: Name(first: p.name),
      organizations: [
        Organization(name: p.businessName, jobTitle: p.businessCategory),
      ],
      notes: [Note(note: 'Met at a BNI 121 Conclave')],
      phones: p.phone.isNotEmpty ? [Phone(number: p.phone)] : const [],
    );
    try {
      // Opens the OS "add contact" screen prefilled — no permission needed.
      await FlutterContacts.native.showCreator(contact: contact);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Couldn't open contacts on this device."),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleMetProvider(conclaveId));

    return AppPage(
      title: 'People you met',
      trailing: IconButton(
        icon: const Icon(CoolIcons.qrCode),
        tooltip: 'Share my card',
        onPressed: () => context.push('/profile/card'),
      ),
      body: people.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not work out who you met.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(peopleMetProvider(conclaveId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: CoolIcons.usersGroup,
              title: 'No connections yet',
              message:
                  'Once the schedule runs, everyone you sit with turns up '
                  'here, ready to save.',
            );
          }
          return ContentWidth(
            max: 520,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.lg,
                context.pagePadding,
                Gap.xl,
              ),
              children: [
                PageHeading(
                  title:
                      '${list.length} ${list.length == 1 ? 'person' : 'people'}',
                  subtitle:
                      'Everyone you shared a table with. Save them before you forget a face.',
                ),
                FadeSlideIn(
                  index: 0,
                  child: SectionCard(
                    gap: 0,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: Gap.lg + 44 + Gap.md,
                            color: context.colors.hairline,
                          ),
                        _MetRow(
                          person: list[i],
                          onSave: () => _save(context, list[i]),
                          onOpen: list[i].uid.isEmpty
                              ? null
                              : () => context.push('/members/${list[i].uid}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetRow extends StatelessWidget {
  final MetPerson person;
  final VoidCallback onSave;
  final VoidCallback? onOpen;

  const _MetRow({
    required this.person,
    required this.onSave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = person.rounds.map((r) => 'R$r').join(', ');
    final sub = [
      if (person.businessCategory.isNotEmpty) person.businessCategory,
      if (person.businessName.isNotEmpty) person.businessName,
    ].join('  ·  ');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 12, Gap.md, 12),
        child: Row(
          children: [
            UserAvatar(name: person.name, photoUrl: null, radius: 22),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name.isEmpty ? 'A member' : person.name,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  if (rounds.isNotEmpty)
                    Text(
                      'Met in $rounds',
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            // Same "Save" pill as the conclave summary.
            Material(
              color: kActionRed.withValues(alpha: 0.08),
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onSave,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CoolIcons.userPlusCornerFill,
                        size: 15,
                        color: kActionRed,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Save',
                        style: context.text.labelMedium?.copyWith(
                          color: kActionRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
