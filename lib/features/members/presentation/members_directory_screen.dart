import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/category_picker.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
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

  // Active filters — null means "no filter".
  String? _membership; // 'BNI' | 'Non-BNI'
  String? _category;
  String? _region;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Member> _filter(List<Member> all) {
    final q = _query.trim().toLowerCase();
    // A fresh list — the caller sorts it, and mutating the provider's own list
    // would be a bug.
    return all.where((m) {
      if (_membership != null && m.membership != _membership) return false;
      if (_category != null && m.businessCategory != _category) return false;
      if (_region != null && (m.region ?? '') != _region) return false;
      if (q.isNotEmpty && !m.searchable.contains(q)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, selected: _category);
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickRegion(List<Member> all) async {
    final regions = all
        .map((m) => m.region)
        .whereType<String>()
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (regions.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in regions)
              ListTile(
                title: Text(r),
                trailing: r == _region
                    ? Icon(Icons.check_rounded, color: ctx.scheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _region = picked);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);
    final myUid = ref.watch(authStateProvider).asData?.value?.uid;

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
          // Put yourself at the very top, so the directory opens on you.
          if (myUid != null) {
            results.sort((a, b) {
              if (a.uid == myUid) return -1;
              if (b.uid == myUid) return 1;
              return 0;
            });
          }
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
              _FilterBar(
                membership: _membership,
                category: _category,
                region: _region,
                onMembership: (m) => setState(() => _membership = m),
                onCategory: _pickCategory,
                onRegion: () => _pickRegion(all),
                onClearCategory: () => setState(() => _category = null),
                onClearRegion: () => setState(() => _region = null),
              ),
              Expanded(
                child: results.isEmpty
                    ? EmptyView(
                        icon: Icons.person_search_rounded,
                        title: all.isEmpty ? 'No members yet' : 'No matches',
                        message: all.isEmpty
                            ? 'Members appear here as people join.'
                            : (_query.isNotEmpty
                                ? 'No one matches “$_query”.'
                                : 'No one matches these filters.'),
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
                              isMe: results[i].uid == myUid,
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
  final bool isMe;

  const _MemberCard({
    required this.member,
    required this.index,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (member.membership.isNotEmpty) member.membership,
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
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.name,
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: Gap.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    'You',
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
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

/// The horizontal filter strip under the search box.
class _FilterBar extends StatelessWidget {
  final String? membership;
  final String? category;
  final String? region;
  final ValueChanged<String?> onMembership;
  final VoidCallback onCategory;
  final VoidCallback onRegion;
  final VoidCallback onClearCategory;
  final VoidCallback onClearRegion;

  const _FilterBar({
    required this.membership,
    required this.category,
    required this.region,
    required this.onMembership,
    required this.onCategory,
    required this.onRegion,
    required this.onClearCategory,
    required this.onClearRegion,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
        children: [
          FilterChip(
            label: const Text('BNI'),
            selected: membership == 'BNI',
            onSelected: (s) => onMembership(s ? 'BNI' : null),
          ),
          const SizedBox(width: Gap.sm),
          FilterChip(
            label: const Text('Non-BNI'),
            selected: membership == 'Non-BNI',
            onSelected: (s) => onMembership(s ? 'Non-BNI' : null),
          ),
          const SizedBox(width: Gap.sm),
          InputChip(
            avatar: const Icon(Icons.category_outlined, size: 18),
            label: Text(category ?? 'Category'),
            selected: category != null,
            onPressed: onCategory,
            onDeleted: category != null ? onClearCategory : null,
          ),
          const SizedBox(width: Gap.sm),
          InputChip(
            avatar: const Icon(Icons.map_outlined, size: 18),
            label: Text(region ?? 'Region'),
            selected: region != null,
            onPressed: onRegion,
            onDeleted: region != null ? onClearRegion : null,
          ),
        ],
      ),
    );
  }
}
