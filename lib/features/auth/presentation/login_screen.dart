import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/phone.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/aero_shards.dart';
import '../../../core/widgets/powered_by_footer.dart';
import '../../active_conclave/presentation/round/round_timer.dart'
    show kDeckBottom;
import '../../active_conclave/presentation/round/deck_footer.dart'
    show roundPanel;
import '../data/auth_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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

      await ref
          .read(authRepositoryProvider)
          .login(identifier, _password.text.trim());
      Analytics.login(_method == LoginMethod.phone ? 'phone' : 'email');
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
    if (s.contains('network')) {
      return 'No connection. Check your signal and try again.';
    }
    if (s.contains('too many')) {
      return 'Too many attempts. Wait a moment, then try again.';
    }
    return raw;
  }

  /// Self-serve reset: SMS code for phone accounts, a link for email ones.
  void _forgotPassword() {
    context.push(
      '/forgot-password?method=${_method == LoginMethod.phone ? 'phone' : 'email'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // A light page now (like the rest of the app): dark status bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        // The keyboard slides OVER the hero rather than squashing it — the form
        // scrolls, the brand stays put.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // The same living background as onboarding, fading out behind the
            // form so the fields stay calm.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.55, 1],
                ).createShader(r),
                child: const AeroShards(count: 90, interactive: false),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(animation: _intro),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // The system navigation bar (gesture pill or 3-button) eats the
                      // bottom edge. Without reserving it here, "New here?" — which the
                      // Spacer pins to the very bottom — gets drawn UNDER the nav bar
                      // and becomes untappable. This reserves it on every device size
                      // rather than hard-coding a margin. The keyboard inset is 0 while
                      // resizeToAvoidBottomInset is false, but we keep it in the sum so
                      // the padding stays correct if that ever changes.
                      final safeBottom = MediaQuery.paddingOf(context).bottom;
                      final bottomInset =
                          MediaQuery.viewInsetsOf(context).bottom +
                          safeBottom +
                          Gap.lg;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          context.pagePadding,
                          Gap.xl,
                          context.pagePadding,
                          bottomInset,
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
                            minHeight:
                                constraints.maxHeight - Gap.xl - bottomInset,
                          ),
                          child: IntrinsicHeight(
                            child: ContentWidth(
                              max: 440,
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _intro,
                                  curve: const Interval(
                                    0.3,
                                    1,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(Gap.lg),
                                        decoration: roundPanel(
                                          context,
                                          radius: 24,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
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
                                                onCountryChanged: (c) =>
                                                    setState(
                                                      () => _country = c,
                                                    ),
                                                onSubmitted:
                                                    _passwordFocus.requestFocus,
                                              )
                                            else
                                              TextFormField(
                                                controller: _identifier,
                                                autofillHints: const [
                                                  AutofillHints.email,
                                                ],
                                                textInputAction:
                                                    TextInputAction.next,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Email address',
                                                      prefixIcon: Icon(
                                                        CoolIcons.mention,
                                                      ),
                                                    ),
                                                onFieldSubmitted: (_) =>
                                                    _passwordFocus
                                                        .requestFocus(),
                                                validator: (v) =>
                                                    (v == null ||
                                                        v.trim().isEmpty)
                                                    ? 'Enter your email address'
                                                    : null,
                                              ),
                                            const SizedBox(height: Gap.md),

                                            TextFormField(
                                              controller: _password,
                                              focusNode: _passwordFocus,
                                              obscureText: _obscure,
                                              autofillHints: const [
                                                AutofillHints.password,
                                              ],
                                              textInputAction:
                                                  TextInputAction.done,
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                prefixIcon: const Icon(
                                                  CoolIcons.lock,
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscure
                                                        ? CoolIcons.eye
                                                        : CoolIcons.eyeOff,
                                                  ),
                                                  tooltip: _obscure
                                                      ? 'Show password'
                                                      : 'Hide password',
                                                  onPressed: () => setState(
                                                    () => _obscure = !_obscure,
                                                  ),
                                                ),
                                              ),
                                              onFieldSubmitted: (_) => _login(),
                                              validator: (v) =>
                                                  (v == null || v.isEmpty)
                                                  ? 'Enter your password'
                                                  : null,
                                            ),

                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _forgotPassword,
                                                child: const Text(
                                                  'Forgot password?',
                                                ),
                                              ),
                                            ),

                                            if (_error != null) ...[
                                              _ErrorNote(message: _error!),
                                              const SizedBox(height: Gap.md),
                                            ],

                                            SizedBox(
                                              height: 52,
                                              child: FilledButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _login,
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: kDeckBottom,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  textStyle: const TextStyle(
                                                    fontFamily:
                                                        'PlusJakartaSans',
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : const Text('Sign in'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: Gap.md),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'New here?',
                                            style: context.text.bodyMedium
                                                ?.copyWith(
                                                  color: context
                                                      .scheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          TextButton(
                                            // push, not go: Create-account stacks ON TOP of
                                            // sign-in, so back returns here.
                                            onPressed: () =>
                                                context.push('/register'),
                                            child: const Text(
                                              'Create an account',
                                            ),
                                          ),
                                        ],
                                      ),
                                      // The rest of the height, then who builds the app.
                                      const Spacer(),
                                      const SizedBox(height: Gap.lg),
                                      const Center(child: PoweredByFooter()),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The brand moment: the app mark and name, then a bold "Welcome back" —
/// light, over the living shard field, in the app's own language.
class _Hero extends StatelessWidget {
  final Animation<double> animation;

  const _Hero({required this.animation});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        top + Gap.lg,
        context.pagePadding,
        0,
      ),
      child: ContentWidth(
        max: 440,
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
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/app_mark.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    '1-2-1 Connect',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xxl),
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
                    style: context.text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Sign in to see your table and your rounds.',
                    style: context.text.bodyLarge?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        child: Transform.translate(
          offset: Offset(0, -6 * (1 - t)),
          child: child,
        ),
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
            Icon(CoolIcons.circleWarning, size: 18, color: c.onDangerContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(
                  color: c.onDangerContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
