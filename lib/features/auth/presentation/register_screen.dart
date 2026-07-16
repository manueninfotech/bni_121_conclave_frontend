import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/business_categories.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../data/auth_repository.dart';

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
  const RegisterScreen({super.key});

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
  final _location = TextEditingController();

  String? _verificationId;
  String? _category;
  bool _isPhoneFlow = false;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
    _name.dispose();
    _businessName.dispose();
    _chapter.dispose();
    _location.dispose();
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
    if (_step == 0) {
      context.pop();
      return;
    }
    // Email flow skips step 1, so going back from the profile lands on creds.
    _goTo(_step == 2 && !_isPhoneFlow ? 0 : _step - 1, forward: false);
  }

  void _error(String msg) {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: context.colors.danger,
      ));
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();

    if (_step == 0) return _submitCredentials();
    if (_step == 1) return _submitOtp();
    return _submitProfile();
  }

  Future<void> _submitCredentials() async {
    if (!(_credsKey.currentState?.validate() ?? false)) return;

    final identifier = _identifier.text.trim();
    _isPhoneFlow = RegExp(r'^\+?[0-9]{10,15}$').hasMatch(identifier);

    // Email: nothing to verify up front, straight to the profile.
    if (!_isPhoneFlow) {
      _goTo(2);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).verifyPhone(
            phone: identifier,
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

    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);

    try {
      if (_isPhoneFlow) {
        // Already signed in via OTP — just set the password and save the profile.
        await repo.registerProfileForPhoneUser(
          user: FirebaseAuth.instance.currentUser!,
          phone: _identifier.text.trim(),
          password: _password.text.trim(),
          name: _name.text.trim(),
          businessName: _businessName.text.trim(),
          businessCategory: _category!,
          location: _location.text.trim(),
          chapter: _chapter.text.trim(),
        );
      } else {
        await repo.registerWithEmailAndPassword(
          email: _identifier.text.trim(),
          password: _password.text.trim(),
          name: _name.text.trim(),
          businessName: _businessName.text.trim(),
          businessCategory: _category!,
          location: _location.text.trim(),
          chapter: _chapter.text.trim(),
        );
      }

      if (!mounted) return;
      if (!_isPhoneFlow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to verify your account.'),
          ),
        );
      }
      context.go('/conclaves');
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _back,
        ),
        title: Text('Step ${_displayStep + 1} of $_totalSteps'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Progress(step: _displayStep, total: _totalSteps),
            Expanded(
              child: ContentWidth(
                max: 440,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.pagePadding),
                  child: AnimatedSwitcher(
                    duration: Motion.normal,
                    switchInCurve: Motion.curve,
                    // Slide in from the direction of travel: forward comes from
                    // the right, back from the left. Motion that contradicts the
                    // navigation makes an app feel unmoored.
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween(
                        begin: Offset(_goingForward ? 0.06 : -0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
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
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.sm,
                context.pagePadding,
                Gap.lg,
              ),
              child: ContentWidth(
                max: 440,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _next,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 2 ? 'Create account' : 'Continue'),
                  ),
                ),
              ),
            ),
          ],
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
            subtitle: 'Use an email address or a phone number with country code.',
          ),
          TextFormField(
            controller: _identifier,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Email or phone',
              hintText: 'you@example.com or +919876543210',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'Enter an email or phone number';
              final isPhone = RegExp(r'^\+?[0-9]{10,15}$').hasMatch(s);
              final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
              if (!isPhone && !isEmail) {
                return 'Enter a valid email, or a phone with country code';
              }
              return null;
            },
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'At least 6 characters',
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
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
            subtitle: 'We sent a code to ${_identifier.text.trim()}.',
          ),
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
            validator: (v) =>
                (v == null || v.trim().length < 6) ? 'Enter the 6-digit code' : null,
          ),
          const SizedBox(height: Gap.md),
          Text(
            "Didn't get it? Go back and check the number.",
            textAlign: TextAlign.center,
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
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
          const _Heading(
            title: 'About your business',
            subtitle: 'This is how other members will know you.',
          ),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
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
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your business name' : null,
          ),
          const SizedBox(height: Gap.md),

          // The field the whole matching engine seats people by, so it says so
          // rather than sitting anonymously among the others.
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true, // long names ellipsize instead of overflowing
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
            validator: (v) => v == null ? 'Choose your business category' : null,
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _location,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. Guntur',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your city' : null,
          ),
          const SizedBox(height: Gap.md),
          TextFormField(
            controller: _chapter,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Chapter (optional)',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
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
          style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          subtitle,
          style: context.text.bodyMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}

/// A thin progress bar rather than a row of numbered circles: it says how far
/// along you are without pretending the steps are navigable.
class _Progress extends StatelessWidget {
  final int step;
  final int total;

  const _Progress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (step + 1) / total),
      duration: Motion.slow,
      curve: Motion.curve,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 3,
        backgroundColor: context.colors.hairline,
      ),
    );
  }
}
