import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/people_met_repository.dart';

/// Everyone you shared a table with at a conclave, across all its rounds — the
/// networking payoff, captured so it survives the day.
class PeopleMetScreen extends ConsumerWidget {
  final String conclaveId;
  const PeopleMetScreen({super.key, required this.conclaveId});

  Future<void> _save(BuildContext context, MetPerson p) async {
    final contact = Contact()
      ..name.first = p.name
      ..organizations = [
        Organization(company: p.businessName, title: p.businessCategory),
      ]
      ..notes = [Note('Met at a BNI 121 Conclave')];
    if (p.phone.isNotEmpty) {
      contact.phones = [Phone(p.phone)];
    }
    try {
      // Opens the OS "add contact" screen prefilled — no permission needed.
      await FlutterContacts.openExternalInsert(contact);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text("Couldn't open contacts on this device."),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleMetProvider(conclaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('People you met'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Share my card',
            onPressed: () => context.push('/profile/card'),
          ),
        ],
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
              icon: Icons.groups_outlined,
              title: 'No connections yet',
              message: 'Once the schedule runs, everyone you sit with turns up '
                  'here — ready to save.',
            );
          }
          return ContentWidth(
            child: ListView.separated(
              padding: context.pageInsets,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
              itemBuilder: (context, i) => _MetCard(
                person: list[i],
                index: i,
                onSave: () => _save(context, list[i]),
                onOpen: list[i].uid.isEmpty
                    ? null
                    : () => context.push('/members/${list[i].uid}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetCard extends StatelessWidget {
  final MetPerson person;
  final int index;
  final VoidCallback onSave;
  final VoidCallback? onOpen;

  const _MetCard({
    required this.person,
    required this.index,
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

    return FadeSlideIn(
      index: index,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                UserAvatar(name: person.name, photoUrl: null, radius: 24),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name.isEmpty ? 'A member' : person.name,
                        style: context.text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                IconButton.filledTonal(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: 'Save to contacts',
                  onPressed: onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
