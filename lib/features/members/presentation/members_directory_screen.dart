import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/members_repository.dart';

/// The app-wide member directory: every registered member, searchable.
///
/// Shows only what is safe for members to see about each other — name, photo,
/// business, category and location. No contact details ever reach this screen;
/// the backend leaves them out.
class MembersDirectoryScreen extends ConsumerStatefulWidget {
  const MembersDirectoryScreen({super.key});

  @override
  ConsumerState<MembersDirectoryScreen> createState() =>
      _MembersDirectoryScreenState();
}

class _MembersDirectoryScreenState
    extends ConsumerState<MembersDirectoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Member> _filter(List<Member> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) => m.searchable.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: members.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load members.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(membersProvider),
        ),
        data: (all) {
          final results = _filter(all);
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  Gap.md,
                  context.pagePadding,
                  Gap.sm,
                ),
                child: ContentWidth(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search name, business, category…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear',
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? EmptyView(
                        icon: Icons.person_search_rounded,
                        title: all.isEmpty
                            ? 'No members yet'
                            : 'No matches',
                        message: all.isEmpty
                            ? 'Members appear here as people join.'
                            : 'No one matches “$_query”.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(membersProvider),
                        child: ContentWidth(
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: context.tabScrollInsets,
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Gap.sm),
                            itemBuilder: (context, i) => _MemberCard(
                              member: results[i],
                              index: i,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final int index;

  const _MemberCard({required this.member, required this.index});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (member.businessCategory.isNotEmpty) member.businessCategory,
      if (member.location.isNotEmpty) _titleCase(member.location),
    ].join('  ·  ');

    return FadeSlideIn(
      index: index,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.xs,
          ),
          leading: UserAvatar(
            name: member.name,
            photoUrl: member.photoUrl,
            radius: 26,
          ),
          title: Text(
            member.name,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/members/${member.uid}'),
        ),
      ),
    );
  }

  // Locations are stored lower-cased for matching; present them nicely.
  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
