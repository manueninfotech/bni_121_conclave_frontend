import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/phone.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/responsive.dart';
import '../data/auth_repository.dart';

/// Sign in.
///
/// A returning member opens this in a car park, two minutes before a conclave
/// starts. So: the brand establishes itself once at the top and then gets out of
/// the way, the form is two fields, and the primary action sits under the thumb.
///
/// The dark hero panel is doing real work. A form floating on flat paper reads
/// as a wireframe; anchoring it under a deep plum header gives the screen a
/// horizon, and it is the one place the brand can be loud without shouting over
/// the content.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Motion.slow,
  )..forward();

  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  /// Phone first — this is a BNI chapter app and almost everyone registers with
  /// a number.
  LoginMethod _method = LoginMethod.phone;
  Country _country = defaultCountry;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Resolve to an unambiguous identity BEFORE it reaches the repository: a
      // real email, or a full E.164 number built from the chosen country.
      final identifier = _method == LoginMethod.phone
          ? Phone.toE164(_country, _identifier.text)
          : _identifier.text.trim();

      await ref.read(authRepositoryProvider).login(identifier, _password.text.trim());
      // The router's redirect handles navigation once auth state changes.
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = _humanise(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Firebase's messages are written for developers.
  ///
  /// "The supplied auth credential is incorrect, malformed or has expired" is
  /// what a member sees for a mistyped password. It tells them nothing they can
  /// act on, and it reads like the app is broken.
  String _humanise(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    final s = raw.toLowerCase();

    if (s.contains('verify your email')) return raw;
    if (s.contains('credential') ||
        s.contains('password') ||
        s.contains('user-not-found') ||
        s.contains('no user record')) {
      return _method == LoginMethod.phone
          ? "We couldn't sign you in. Check the number and password — and that the country code is right."
          : "We couldn't sign you in. Check your email and password.";
    }
    if (s.contains('network')) return 'No connection. Check your signal and try again.';
    if (s.contains('too many')) return 'Too many attempts. Wait a moment, then try again.';
    return raw;
  }

  Future<void> _forgotPassword() async {
    // A phone account has no mailbox to send to. Say so here, rather than
    // letting them type an address and silently doing nothing.
    if (_method == LoginMethod.phone) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.lock_reset_rounded, color: ctx.scheme.primary),
          title: const Text('Reset by phone'),
          content: const Text(
            'Your account is registered to a phone number, so there is no email '
            'address we can send a reset link to. Ask your conclave admin to '
            'reset it for you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final controller = TextEditingController(text: _identifier.text.trim());
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Gap.xl,
          right: Gap.xl,
          top: Gap.sm,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + Gap.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset your password',
              style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              "We'll email you a link to set a new one.",
              style: ctx.text.bodyMedium?.copyWith(color: ctx.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: Gap.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Send link'),
              ),
            ),
          ],
        ),
      ),
    );

    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        // Never confirms whether an address is registered — that would let
        // anyone enumerate members.
        _toast('If that address has an account, a reset link is on its way.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _humanise(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // The hero is dark, so the status bar icons must be light — otherwise the
    // clock is near-invisible against it. Scoped to this screen; the rest of the
    // app follows the theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: Scaffold(
      // The keyboard slides OVER the hero rather than squashing it — the form
      // scrolls, the brand stays put.
      resizeToAvoidBottomInset: false,
      body: Column(
        // stretch, not the default centre: without it the hero shrink-wraps to
        // its text and leaves pale margins down both sides of a panel that is
        // meant to be full-bleed.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(animation: _intro),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  Gap.xl,
                  context.pagePadding,
                  MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
                ),
                child: ConstrainedBox(
                  // Fill the space below the hero so the form can push "New
                  // here?" to the bottom instead of leaving a dead half-screen.
                  //
                  // minHeight alone is not enough: a SingleChildScrollView hands
                  // its child an UNBOUNDED max height, so the Column would
                  // shrink-wrap and the Spacer inside it (an Expanded) would
                  // throw "non-zero flex but incoming height constraints are
                  // unbounded". IntrinsicHeight is what actually bounds it.
                  // Cheap here — the subtree is a short form.
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - Gap.xl - Gap.lg,
                  ),
                  child: IntrinsicHeight(
                    child: ContentWidth(
                    max: 440,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _intro,
                        curve: const Interval(0.3, 1, curve: Curves.easeOut),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        MethodToggle(
                          value: _method,
                          onChanged: (m) => setState(() {
                            _method = m;
                            _identifier.clear();
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: Gap.md),

                        // Asking which, rather than sniffing it from one field,
                        // is what lets the phone path carry a country code — and
                        // it removes the guess that broke sign-in.
                        if (_method == LoginMethod.phone)
                          PhoneField(
                            controller: _identifier,
                            country: _country,
                            onCountryChanged: (c) => setState(() => _country = c),
                            onSubmitted: _passwordFocus.requestFocus,
                          )
                        else
                          TextFormField(
                            controller: _identifier,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your email address'
                                : null,
                          ),
                        const SizedBox(height: Gap.md),

                        TextFormField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onFieldSubmitted: (_) => _login(),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter your password' : null,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),

                        if (_error != null) ...[
                          _ErrorNote(message: _error!),
                          const SizedBox(height: Gap.md),
                        ],

                        PrimaryButton(
                          label: 'Sign in',
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _login,
                        ),

                        // Fills the space rather than leaving a dead half-screen
                        // below the form.
                        const Spacer(),
                        const SizedBox(height: Gap.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New here?',
                              style: context.text.bodyMedium
                                  ?.copyWith(color: context.scheme.onSurfaceVariant),
                            ),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

/// The brand moment.
///
/// One deep panel at the top, so the form below has something to sit against.
/// The alternative — a small logo floating on paper — is what made the screen
/// read as a placeholder.
class _Hero extends StatelessWidget {
  final Animation<double> animation;

  const _Hero({required this.animation});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
      child: Stack(
        children: [
          // Both gradients fill the WHOLE panel, outside the padding.
          //
          // Previously the bloom lived inside the padded child, so it filled only
          // the content box — and the radial hadn't faded to zero by that box's
          // edge, leaving hard rectangular seams inside the panel that looked
          // like a rendering fault.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppGradients.hero),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.8),
                  radius: 1.1,
                  colors: [
                    AppColors.crimson.withValues(alpha: 0.38),
                    AppColors.crimson.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Gap.xl, top + Gap.xl, Gap.xl, Gap.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0, 0.7, curve: Motion.spring),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.groups_rounded, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.2, 1, curve: Curves.easeOut),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: context.text.displaySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'Sign in to see your table and your rounds.',
                        style: context.text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An inline error that stays put until it's dealt with.
///
/// A snackbar slides away before a failed sign-in has been read, and a failed
/// sign-in is something you act on.
class _ErrorNote extends StatelessWidget {
  final String message;
  const _ErrorNote({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.normal,
      curve: Motion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, -6 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: c.dangerContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.danger.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: c.onDangerContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(color: c.onDangerContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
