import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/business_categories.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _location = TextEditingController();
  final _chapter = TextEditingController();
  String? _category;

  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    _location.dispose();
    _chapter.dispose();
    super.dispose();
  }

  /// Fills the form from the live profile the first time it arrives. Guarded so a
  /// later stream tick can't wipe out what the user is halfway through typing.
  void _seed(UserProfile p) {
    if (_seeded) return;
    _seeded = true;
    _name.text = p.name;
    _businessName.text = p.businessName;
    _location.text = p.location;
    _chapter.text = p.chapter ?? '';
    _category = bniBusinessCategories.contains(p.businessCategory)
        ? p.businessCategory
        : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text,
            businessName: _businessName.text,
            businessCategory: _category!,
            location: _location.text,
            chapter: _chapter.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (p) {
          if (p == null) {
            return const EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Profile not found',
            );
          }
          _seed(p);

          return ContentWidth(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(context.pagePadding),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: Gap.lg),

                  TextFormField(
                    controller: _businessName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),

                  // The important one. Everything the engine does hangs off it.
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true, // long names must ellipsize, not overflow
                    decoration: const InputDecoration(
                      labelText: 'Business category',
                      prefixIcon: Icon(Icons.category_outlined),
                      helperText: 'No two people of the same category share a table',
                      helperMaxLines: 2,
                    ),
                    items: [
                      for (final c in bniBusinessCategories)
                        DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                    validator: (v) =>
                        v == null ? 'Choose your business category' : null,
                  ),
                  const SizedBox(height: Gap.lg),

                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.place_outlined),
                      helperText: 'e.g. Guntur',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your location'
                        : null,
                  ),
                  const SizedBox(height: Gap.lg),

                  TextFormField(
                    controller: _chapter,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Chapter (optional)',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                  ),

                  const SizedBox(height: Gap.xl),

                  // Changing category cannot corrupt a running event: the roster is
                  // frozen into the conclave when its schedule is generated. Say so,
                  // so nobody is afraid to correct a mistake mid-season.
                  Card(
                    color: context.colors.infoContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: context.colors.onInfoContainer),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(
                              'Changes apply to conclaves scheduled from now on. '
                              'A conclave already under way keeps the details it '
                              'started with.',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onInfoContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: Gap.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
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
