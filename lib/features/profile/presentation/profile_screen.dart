import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Signing out at a live event means re-authenticating in a room with no
    // signal. Worth one tap of confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to take part in a conclave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authRepositoryProvider).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (p) {
          if (p == null) {
            // The old screen showed users the raw string "Profile document does
            // not exist in Firestore." — which tells them nothing they can act on.
            return EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Profile not found',
              message: 'We could not find your details. Try signing out and back '
                  'in, or contact the admin.',
              action: FilledButton(
                onPressed: () => _confirmLogout(context, ref),
                child: const Text('Sign out'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: ContentWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // A tab root: content scrolls behind the floating nav bar, so
                // grow the bottom to keep the last card clear of it.
                padding: context.tabScrollInsets,
                children: [
                  FadeSlideIn(index: 0, child: _Header(profile: p)),
                  const SizedBox(height: Gap.xl),

                  FadeSlideIn(
                    index: 1,
                    child: _Section(
                      title: 'Business',
                      children: [
                        InfoRow(
                          icon: Icons.business_outlined,
                          label: 'Business name',
                          value: p.businessName.isEmpty ? 'Not set' : p.businessName,
                        ),
                        InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Business category',
                          value: p.businessCategory.isEmpty
                              ? 'Not set'
                              : p.businessCategory,
                        ),
                        if (p.chapter != null && p.chapter!.isNotEmpty)
                          InfoRow(
                            icon: Icons.groups_2_outlined,
                            label: 'Chapter',
                            value: p.chapter!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.md),

                  FadeSlideIn(
                    index: 2,
                    child: _Section(
                      title: 'Contact',
                      children: [
                        InfoRow(
                          icon: Icons.phone_iphone_rounded,
                          label: 'Phone',
                          value: p.phone.isEmpty ? 'Not set' : p.phone,
                        ),
                        InfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          // Never surface the synthetic sign-in address.
                          value: p.email.isEmpty ? 'Not set' : p.email,
                        ),
                        InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: p.location.isEmpty ? 'Not set' : p.location,
                        ),
                        InfoRow(
                          icon: Icons.public,
                          label: 'Country',
                          value: p.country,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.xl),

                  FadeSlideIn(
                    index: 3,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.scheme.secondaryContainer,
                          child: Icon(Icons.swap_horiz_rounded,
                              color: context.scheme.onSecondaryContainer),
                        ),
                        title: const Text('My referrals'),
                        subtitle: const Text(
                          'Who you referred, and who referred you',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/profile/referrals'),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),

                  // Category is the field the engine seats people by, so a mistake
                  // there used to be permanent — there was no way to change it.
                  FadeSlideIn(
                    index: 4,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your business category decides who you sit with',
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: Gap.xs),
                            Text(
                              'No two people of the same category ever share a table. '
                              'If yours is wrong, fix it here — changes apply to '
                              'future conclaves.',
                              style: context.text.bodySmall?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Gap.lg),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => context.push('/profile/edit'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit profile'),
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
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Hero(
          tag: 'profile-avatar',
          child: UserAvatar(
            name: profile.name,
            photoUrl: profile.photoUrl,
            radius: 44,
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(
          profile.name.isEmpty ? 'Unnamed' : profile.name,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (profile.businessCategory.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          StatusBadge(
            label: profile.businessCategory,
            tone: StatusTone.info,
            icon: Icons.category_outlined,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}
