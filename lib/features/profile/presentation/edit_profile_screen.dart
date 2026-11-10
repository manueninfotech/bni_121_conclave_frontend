import 'package:flutter/material.dart';
import '../../../core/widgets/app_spinner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/business_categories.dart';
import '../../../core/domain/phone.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_picker.dart';
import '../../../core/config/categories_provider.dart';
import '../../../core/widgets/membership_toggle.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../data/profile_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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
  final _lookingFor = TextEditingController();
  final _canOffer = TextEditingController();
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
    _lookingFor.dispose();
    _canOffer.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Presents the photo options and runs the chosen one.
  Future<void> _editPhoto(bool hasPhoto) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      backgroundColor: context.scheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.md),
                child: Text(
                  'Profile photo',
                  style: ctx.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SectionCard(
                gap: 0,
                padding: EdgeInsets.zero,
                children: [
                  CardRow(
                    icon: CoolIcons.camera,
                    title: 'Take a photo',
                    onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
                  ),
                  CardRow(
                    icon: CoolIcons.images,
                    title: 'Choose from gallery',
                    onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
                  ),
                  if (hasPhoto)
                    CardRow(
                      icon: CoolIcons.trash,
                      title: 'Remove photo',
                      tint: ctx.colors.danger,
                      trailing: const SizedBox.shrink(),
                      onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
                    ),
                ],
              ),
            ],
          ),
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
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Could not update your photo. ${e.toString().replaceFirst('Exception: ', '')}',
              ),
              backgroundColor: context.colors.danger,
            ),
          );
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
    _lookingFor.text = p.lookingFor;
    _canOffer.text = p.canOffer;
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
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Choose whether you are a BNI or Non-BNI member.',
            ),
            backgroundColor: context.colors.danger,
          ),
        );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
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
            lookingFor: _lookingFor.text,
            canOffer: _canOffer.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
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

    return AppPage(
      title: 'Edit profile',
      action: profile.asData?.value == null
          ? null
          : AppPrimaryButton(
              label: 'Save changes',
              busy: _saving,
              onPressed: _save,
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
            return const EmptyView(
              icon: CoolIcons.userCloseCorner,
              title: 'Profile not found',
            );
          }
          _seed(p);

          return ContentWidth(
            max: 520,
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  Gap.lg,
                  context.pagePadding,
                  Gap.xl,
                ),
                children: [
                  // Photo + who you are, on one card.
                  Container(
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: pagePanel(context),
                    child: Row(
                      children: [
                        _PhotoEditor(
                          name: p.name,
                          photoUrl: p.photoUrl,
                          busy: _photoBusy,
                          onEdit: () => _editPhoto(p.photoUrl != null),
                        ),
                        const SizedBox(width: Gap.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name.isEmpty ? 'Your profile' : p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: Gap.xs),
                              GestureDetector(
                                onTap: _photoBusy
                                    ? null
                                    : () => _editPhoto(p.photoUrl != null),
                                child: Text(
                                  p.photoUrl == null
                                      ? 'Add a photo'
                                      : 'Change photo',
                                  style: context.text.bodyMedium?.copyWith(
                                    color: kActionRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.xl),

                  const SectionLabel('Contact'),
                  SectionCard(
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(CoolIcons.user),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
                      ),
                      PhoneField(
                        controller: _phone,
                        country: _country,
                        onCountryChanged: (c) => setState(() => _country = c),
                      ),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(CoolIcons.mention),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Enter your email address';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(s)) {
                            return 'That does not look like an email address';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),

                  const SectionLabel('Business'),
                  SectionCard(
                    children: [
                      TextFormField(
                        controller: _businessName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Business name',
                          prefixIcon: Icon(CoolIcons.building2),
                        ),
                      ),
                      // The important one. Everything the engine does hangs off it.
                      CategoryPickerField(
                        value: _category,
                        onChanged: (v) => setState(() => _category = v),
                        categories: ref.watch(categoriesProvider),
                      ),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(CoolIcons.mapPin),
                          helperText: 'e.g. Guntur',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your location'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),

                  const SectionLabel('BNI'),
                  SectionCard(
                    children: [
                      TextFormField(
                        controller: _chapter,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Chapter (optional)',
                          prefixIcon: Icon(CoolIcons.usersGroup),
                        ),
                      ),
                      TextFormField(
                        controller: _region,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Region (optional)',
                          hintText: 'e.g. Guntur Region',
                          prefixIcon: Icon(CoolIcons.map),
                        ),
                      ),
                      MembershipToggle(
                        value: _membership,
                        onChanged: (m) => setState(() => _membership = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),

                  const SectionLabel('Networking'),
                  SectionCard(
                    children: [
                      TextFormField(
                        controller: _lookingFor,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "What you're looking for (optional)",
                          hintText: 'e.g. Introductions to restaurant owners',
                          prefixIcon: Icon(CoolIcons.search),
                          helperText: 'Other members can find you by this',
                          helperMaxLines: 2,
                        ),
                      ),
                      TextFormField(
                        controller: _canOffer,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'What you can offer (optional)',
                          hintText: 'e.g. Commercial interior fit-outs',
                          prefixIcon: Icon(CoolIcons.handCoins),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),

                  // Changing category cannot corrupt a running event: the roster is
                  // frozen into the conclave when its schedule is generated. Say so,
                  // so nobody is afraid to correct a mistake mid-season.
                  const PageNote(
                    'Changes apply to conclaves scheduled from now on. A conclave '
                    'already under way keeps the details it started with.',
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
            UserAvatar(name: name, photoUrl: photoUrl, radius: 40),
            if (busy)
              Positioned.fill(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  child: const AppSpinner(size: 26, color: Colors.white),
                ),
              ),
            // The little camera badge that says "this is tappable".
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kActionRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  CoolIcons.cameraFill,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
