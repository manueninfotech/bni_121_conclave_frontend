import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/phone.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_picker.dart';
import '../../../core/config/categories_provider.dart';
import '../../../core/widgets/membership_toggle.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/responsive.dart';
import '../data/auth_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';
import 'package:conclave_1_2_1/core/widgets/app_dialog.dart';
import 'package:conclave_1_2_1/core/widgets/aero_shards.dart';
import 'package:conclave_1_2_1/core/widgets/page_kit.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/round/round_timer.dart'
    show kDeckBottom;

/// Registration.
///
/// Material's `Stepper` was doing this before — it stacks every step's title on
/// screen at once, so the form competes with a table of contents nobody reads,
/// and it looks unmistakably like a 2016 Android app.
///
/// This is the pattern modern onboarding actually uses: one question at a time,
/// a thin progress bar, and the step slides in the direction you travelled so
/// going back feels like going back.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.previewStep});

  /// Design-review tests only: open on this step without touching Firebase.
  @visibleForTesting
  final int? previewStep;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;
  bool _goingForward = true;

  final _credsKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _profileKey = GlobalKey<FormState>();

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _chapter = TextEditingController();
  final _region = TextEditingController();
  final _location = TextEditingController();

  /// "BNI" or "Non-BNI" — no default; the member must choose.
  String? _membership;

  /// The contact they did NOT sign up with. The spec asks for both
  /// ("phonenumber/email (autofilled) and ask leftover"), and it is the only way
  /// the admin can reach a member: a phone account's sign-in address is
  /// synthetic and no mailbox receives it.
  final _altEmail = TextEditingController();
  final _altPhone = TextEditingController();
  Country _altCountry = defaultCountry;

  String? _verificationId;
  String? _category;
  bool _isLoading = false;
  bool _obscure = true;

  /// Chosen explicitly rather than sniffed from what was typed.
  LoginMethod _method = LoginMethod.phone;
  Country _country = defaultCountry;

  /// Resuming an already-authenticated phone account.
  ///
  /// Two ways we get here already signed in:
  ///  - the OTP just succeeded and Firebase's auth-state change rebuilt this
  ///    screen from scratch (a signed-in→out transition refreshes the router),
  ///  - the app reopened on a registration that was interrupted after the OTP
  ///    but before the profile was saved, and the router sent us back to finish.
  ///
  /// Either way the phone is already verified and the number is known from the
  /// account, so we skip the number+OTP steps and go straight to collecting the
  /// password and profile. Without this, that auth-state rebuild dropped the
  /// wizard back to step 1.
  bool _resuming = false;
  String? _resumedPhone;

  @override
  void initState() {
    super.initState();
    if (widget.previewStep != null) {
      _step = widget.previewStep!;
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _resuming = true;
      _resumedPhone = user.phoneNumber;
      _method = LoginMethod.phone;
      _step = 2; // straight to the profile (which also asks for a password)
    }
  }

  bool get _isPhoneFlow => _method == LoginMethod.phone;

  /// The full E.164 number, e.g. +919515409973. Built once, here, so the OTP,
  /// the account identity and the stored profile can never disagree. When
  /// resuming, it comes from the already-verified account.
  String get _e164 => (_resuming && (_resumedPhone?.isNotEmpty ?? false))
      ? _resumedPhone!
      : Phone.toE164(_country, _identifier.text);

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
    _name.dispose();
    _businessName.dispose();
    _chapter.dispose();
    _region.dispose();
    _location.dispose();
    _altEmail.dispose();
    _altPhone.dispose();
    super.dispose();
  }

  /// Steps shown for the CURRENT flow. Email registration has no OTP step, so
  /// the progress bar must not pretend there are three.
  int get _totalSteps => _isPhoneFlow ? 3 : 2;
  int get _displayStep => _isPhoneFlow ? _step : (_step == 2 ? 1 : _step);

  void _goTo(int step, {bool forward = true}) {
    setState(() {
      _goingForward = forward;
      _step = step;
    });
  }

  void _back() {
    // Resuming an already-verified account: there is no earlier step to walk
    // back to (the number and OTP are behind us). Back means "cancel setup",
    // which signs out — the router then lands us on the login screen.
    if (_resuming) {
      _cancelResume();
      return;
    }
    if (_step == 0) {
      context.pop();
      return;
    }
    // Email flow skips step 1, so going back from the profile lands on creds.
    _goTo(_step == 2 && !_isPhoneFlow ? 0 : _step - 1, forward: false);
  }

  Future<void> _cancelResume() async {
    final leave = await showAppConfirm(
      context,
      icon: CoolIcons.logOut,
      title: 'Cancel setup?',
      message:
          'Your number is verified, but your account is not finished yet. You '
          'can complete it later by registering with the same number.',
      confirmLabel: 'Cancel setup',
      cancelLabel: 'Keep going',
      destructive: true,
    );
    if (leave == true) {
      // Signing out flips auth state; the router redirect takes it from here.
      await ref.read(authRepositoryProvider).logout();
    }
  }

  void _error(String msg) {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg.replaceFirst('Exception: ', '')),
          backgroundColor: context.colors.danger,
        ),
      );
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();

    if (_step == 0) return _submitCredentials();
    if (_step == 1) return _submitOtp();
    return _submitProfile();
  }

  Future<void> _submitCredentials() async {
    if (!(_credsKey.currentState?.validate() ?? false)) return;

    // Email: nothing to verify up front, straight to the profile.
    if (!_isPhoneFlow) {
      _goTo(2);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhone(
            phone: _e164,
            onCodeSent: (verId) {
              if (!mounted) return;
              setState(() {
                _verificationId = verId;
                _isLoading = false;
              });
              _goTo(1);
            },
            onError: (err) {
              if (!mounted) return;
              setState(() => _isLoading = false);
              _error(err);
            },
          );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _error(e.toString());
    }
  }

  Future<void> _submitOtp() async {
    if (!(_otpKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .submitOtp(_verificationId!, _otp.text.trim());
      if (!mounted) return;
      setState(() => _isLoading = false);
      _goTo(2);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _error(e.toString());
    }
  }

  Future<void> _submitProfile() async {
    if (!(_profileKey.currentState?.validate() ?? false)) return;
    // The membership toggle isn't a FormField, so check it explicitly.
    if (_membership == null) {
      _error('Choose whether you are a BNI or Non-BNI member.');
      return;
    }

    // Category is a FormField (validated above) and membership is checked
    // explicitly, but read them into locals so a stray null can never reach a
    // `!` and crash with the opaque "Null check operator used on a null value".
    final category = _category;
    if (category == null || category.isEmpty) {
      setState(() => _isLoading = false);
      _error('Choose your business category.');
      return;
    }
    final membership = _membership!;

    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);

    try {
      if (_isPhoneFlow) {
        // Already signed in via OTP — just set the password and save the profile.
        // The account can go missing here if the OTP session was lost before the
        // profile was saved (a long pause on this form, or a cold reopen after
        // the session expired). Recover with a clear message instead of crashing
        // on a null `currentUser`.
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() => _isLoading = false);
          _error(
            'Your verification session ended before we could finish. '
            'Please register again with the same number.',
          );
          await ref.read(authRepositoryProvider).logout();
          return;
        }
        await repo.registerProfileForPhoneUser(
          user: user,
          phone: _e164,
          email: _altEmail.text.trim(),
          password: _password.text.trim(),
          name: _name.text.trim(),
          businessName: _businessName.text.trim(),
          businessCategory: category,
          location: _location.text.trim(),
          chapter: _chapter.text.trim(),
          region: _region.text.trim(),
          membership: membership,
        );
      } else {
        await repo.registerWithEmailAndPassword(
          email: _identifier.text.trim(),
          phone: Phone.toE164(_altCountry, _altPhone.text),
          password: _password.text.trim(),
          name: _name.text.trim(),
          businessName: _businessName.text.trim(),
          businessCategory: category,
          location: _location.text.trim(),
          chapter: _chapter.text.trim(),
          region: _region.text.trim(),
          membership: membership,
        );
      }

      Analytics.signUp(_isPhoneFlow ? 'phone' : 'email');
      if (!mounted) return;
      if (!_isPhoneFlow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to verify your account.'),
          ),
        );
      }
      context.go('/conclaves');
    } catch (e, st) {
      // Keep the stack for diagnosis — a bare message like "Null check operator
      // used on a null value" is useless without the line it came from.
      debugPrint('Registration failed: $e\n$st');
      _error(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // On the first step, let the system back gesture pop the route (back to
      // sign-in). On later steps, intercept it so hardware back walks BACK a
      // step — matching the app-bar arrow — instead of abandoning the form.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isLoading) return;
        _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          body: Stack(
            children: [
              // The sign-in screen's living background, faint behind the header.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: MediaQuery.sizeOf(context).height * 0.32,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.4, 1],
                  ).createShader(r),
                  child: const AeroShards(count: 70, interactive: false),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      title: _resuming
                          ? 'Finish your account'
                          : 'Create account',
                      step: _resuming
                          ? null
                          : '${_displayStep + 1} of $_totalSteps',
                      onBack: _isLoading ? null : _back,
                    ),
                    if (!_resuming)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.pagePadding,
                          Gap.xs,
                          context.pagePadding,
                          0,
                        ),
                        child: ContentWidth(
                          max: 440,
                          child: _Progress(
                            step: _displayStep,
                            total: _totalSteps,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ContentWidth(
                        max: 440,
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            Gap.xl,
                            context.pagePadding,
                            Gap.xl,
                          ),
                          child: AnimatedSwitcher(
                            duration: Motion.normal,
                            switchInCurve: Motion.curve,
                            // Slide in from the direction of travel.
                            transitionBuilder: (child, animation) =>
                                SlideTransition(
                                  position: Tween(
                                    begin: Offset(
                                      _goingForward ? 0.06 : -0.06,
                                      0,
                                    ),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: switch (_step) {
                                0 => _credentials(),
                                1 => _otpStep(),
                                _ => _profile(),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The one action, pinned at the bottom (as on the conclave page).
                    Container(
                      decoration: BoxDecoration(
                        color: context.scheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        Gap.md,
                        context.pagePadding,
                        Gap.md,
                      ),
                      child: ContentWidth(
                        max: 440,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _next,
                            style: FilledButton.styleFrom(
                              backgroundColor: kDeckBottom,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _step == 2 ? 'Create account' : 'Continue',
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _credentials() {
    return Form(
      key: _credsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            title: 'Create your account',
            subtitle: 'We\'ll use this to sign you in.',
          ),
          SectionCard(
            children: [
              MethodToggle(
                value: _method,
                onChanged: (m) => setState(() {
                  _method = m;
                  _identifier.clear();
                }),
              ),
              const SizedBox(height: Gap.md),

              if (_isPhoneFlow)
                PhoneField(
                  controller: _identifier,
                  country: _country,
                  onCountryChanged: (c) => setState(() => _country = c),
                )
              else
                TextFormField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(CoolIcons.mention),
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
              // Phone accounts set their password on the profile step, not here.
              // A phone user is signed in by the OTP partway through, and that
              // auth-state change rebuilds this screen — so a password typed here
              // would be lost and have to be re-entered. Email has no OTP, so it
              // stays.
              if (!_isPhoneFlow) ...[
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Create a password',
                    prefixIcon: const Icon(CoolIcons.lock),
                    helperText:
                        "New password — you'll use it to sign in. At least 6 characters.",
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? CoolIcons.eye : CoolIcons.eyeOff),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.xl),
          _WhatsNext(phone: _isPhoneFlow),
          const SizedBox(height: Gap.lg),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () =>
                        context.canPop() ? context.pop() : context.go('/login'),
              style: TextButton.styleFrom(
                foregroundColor: context.scheme.onSurfaceVariant,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign in',
                      style: TextStyle(
                        color: context.scheme.onSurface,
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
    );
  }

  Widget _otpStep() {
    return Form(
      key: _otpKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            title: 'Verify your phone',
            subtitle: 'We sent a 6-digit code to $_e164.',
          ),
          SectionCard(
            children: [
              TextFormField(
                controller: _otp,
                keyboardType: TextInputType.number,
                autofocus: true,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  hintText: '······',
                  counterText: '',
                ),
                maxLength: 6,
                validator: (v) => (v == null || v.trim().length < 6)
                    ? 'Enter the 6-digit code'
                    : null,
              ),
              const SizedBox(height: Gap.md),
              Text(
                "Didn't get it? Go back and check the number.",
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profile() {
    return Form(
      key: _profileKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            title: _isPhoneFlow ? 'Finish your account' : 'About you',
            subtitle: _isPhoneFlow
                ? 'Your number is verified. Set a password and tell us about you.'
                : 'This is how other members will know you.',
          ),

          // The phone flow collects its password here — see the note in
          // _credentials(). Asked exactly once, on the one step that survives
          // the mid-registration auth-state rebuild.
          if (_isPhoneFlow) ...[
            const SectionLabel('Sign-in'),
            SectionCard(
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Create a password',
                    prefixIcon: const Icon(CoolIcons.lock),
                    helperText:
                        "New password — you'll use it to sign in. At least 6 characters.",
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? CoolIcons.eye : CoolIcons.eyeOff),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),
          ],

          const SectionLabel('Contact'),
          SectionCard(
            children: [
              // The leftover contact. Asked here rather than at the credentials step
              // so signing up stays two fields — this is the "tell us about
              // yourself" part, and it belongs with the rest of the profile.
              if (_isPhoneFlow)
                TextFormField(
                  controller: _altEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(CoolIcons.mention),
                    helperText: 'So the admin can reach you about the conclave',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Enter your email address';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return 'That does not look like an email address';
                    }
                    return null;
                  },
                )
              else
                PhoneField(
                  controller: _altPhone,
                  country: _altCountry,
                  onCountryChanged: (c) => setState(() => _altCountry = c),
                  label: 'Phone number',
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),

          const SectionLabel('You and your business'),
          SectionCard(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(CoolIcons.user),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _businessName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  prefixIcon: Icon(CoolIcons.building2),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your business name'
                    : null,
              ),
              const SizedBox(height: Gap.md),

              // The field the whole matching engine seats people by, so it says so
              // rather than sitting anonymously among the others.
              CategoryPickerField(
                value: _category,
                onChanged: (v) => setState(() => _category = v),
                categories: ref.watch(categoriesProvider),
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _location,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Guntur',
                  prefixIcon: Icon(CoolIcons.mapPin),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your city' : null,
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
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _region,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Region (optional)',
                  hintText: 'e.g. Guntur Region',
                  prefixIcon: Icon(CoolIcons.map),
                ),
              ),
              const SizedBox(height: Gap.lg),

              MembershipToggle(
                value: _membership,
                onChanged: (m) => setState(() => _membership = m),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Heading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          subtitle,
          style: context.text.bodyLarge?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}

/// The road ahead, so the first step explains the whole flow.
class _WhatsNext extends StatelessWidget {
  final bool phone;
  const _WhatsNext({required this.phone});

  @override
  Widget build(BuildContext context) {
    final steps = [
      if (phone) ('Verify your number', 'We text you a 6-digit code.'),
      (
        'Tell us about your business',
        'Your category keeps tables free of competitors.',
      ),
      (
        'Join a conclave',
        'Register, then see your table and partners on the day.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('What happens next'),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, 0, Gap.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.scheme.surfaceContainerHighest.withValues(
                      alpha: 0.8,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: context.text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].$1,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$2,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Back · title · step pill.
class _TopBar extends StatelessWidget {
  final String title;
  final String? step;
  final VoidCallback? onBack;
  const _TopBar({
    required this.title,
    required this.step,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding - Gap.sm,
        Gap.xs,
        context.pagePadding,
        0,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(CoolIcons.arrowLeft),
              tooltip: 'Back',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: step == null
                  ? null
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          step!,
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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

/// Segmented progress: one short ink bar per step, filled as you go.
class _Progress extends StatelessWidget {
  final int step;
  final int total;

  const _Progress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.normal,
              curve: Motion.curve,
              height: 4,
              decoration: BoxDecoration(
                color: i <= step
                    ? context.scheme.onSurface
                    : context.scheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
