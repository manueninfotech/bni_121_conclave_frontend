import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/business_categories.dart';
import '../../../core/domain/phone.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_picker.dart';
import '../../../core/widgets/membership_toggle.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/user_avatar.dart';
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
  final _region = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _category;
  String? _membership;
  Country _country = defaultCountry;

  bool _seeded = false;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    _location.dispose();
    _chapter.dispose();
    _region.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Presents the photo options and runs the chosen one.
  Future<void> _editPhoto(bool hasPhoto) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: ctx.scheme.error),
                title: Text('Remove photo',
                    style: TextStyle(color: ctx.scheme.error)),
                onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    setState(() => _photoBusy = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      if (action == _PhotoAction.remove) {
        await repo.removeAvatar();
      } else {
        final picked = await ImagePicker().pickImage(
          source: action == _PhotoAction.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          // Downscale before upload: an avatar never needs full-res, and a 6MB
          // camera shot on venue wifi would just hang.
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked == null) {
          if (mounted) setState(() => _photoBusy = false);
          return;
        }
        await repo.uploadAvatar(picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Could not update your photo. ${e.toString()
                .replaceFirst('Exception: ', '')}'),
            backgroundColor: context.colors.danger,
          ));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
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
    _region.text = p.region ?? '';
    _email.text = p.email;
    _category = bniBusinessCategories.contains(p.businessCategory)
        ? p.businessCategory
        : null;
    _membership = p.membership.isEmpty ? null : p.membership;

    // Split the stored E.164 number back into a country and a national part, so
    // the picker shows the right flag rather than resetting everyone to India.
    if (p.phone.isNotEmpty) {
      final (country, national) = Phone.parseE164(p.phone);
      _country = country;
      _phone.text = national;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_membership == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Choose whether you are a BNI or Non-BNI member.'),
          backgroundColor: context.colors.danger,
        ));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text,
            businessName: _businessName.text,
            businessCategory: _category!,
            location: _location.text,
            email: _email.text,
            phone: _phone.text.trim().isEmpty
                ? ''
                : Phone.toE164(_country, _phone.text),
            chapter: _chapter.text,
            region: _region.text,
            membership: _membership!,
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
                padding: context.pageInsets,
                children: [
                  Center(
                    child: _PhotoEditor(
                      name: p.name,
                      photoUrl: p.photoUrl,
                      busy: _photoBusy,
                      onEdit: () => _editPhoto(p.photoUrl != null),
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
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

                  PhoneField(
                    controller: _phone,
                    country: _country,
                    onCountryChanged: (c) => setState(() => _country = c),
                  ),
                  const SizedBox(height: Gap.lg),

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Enter your email address';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                        return 'That does not look like an email address';
                      }
                      return null;
                    },
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
                  CategoryPickerField(
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
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
                  const SizedBox(height: Gap.lg),

                  TextFormField(
                    controller: _region,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Region (optional)',
                      hintText: 'e.g. Guntur Region',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),

                  MembershipToggle(
                    value: _membership,
                    onChanged: (m) => setState(() => _membership = m),
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

enum _PhotoAction { camera, gallery, remove }

/// The avatar with an edit affordance, and a spinner overlay while a new photo
/// uploads.
class _PhotoEditor extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool busy;
  final VoidCallback onEdit;

  const _PhotoEditor({
    required this.name,
    required this.photoUrl,
    required this.busy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: busy ? null : onEdit,
        child: Stack(
          children: [
            UserAvatar(name: name, photoUrl: photoUrl, radius: 52),
            if (busy)
              Positioned.fill(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  child: const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // The little camera badge that says "this is tappable".
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
