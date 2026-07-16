import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../data/auth_repository.dart';

/// Sign in.
///
/// The first thing a returning member sees, so it is deliberately quiet: a
/// wordmark, two fields, one primary action. No hero illustration, no 80px
/// padlock — a lock icon tells a user nothing they don't know and eats the space
/// where the form should be.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
      await ref.read(authRepositoryProvider).login(
            _identifier.text.trim(),
            _password.text.trim(),
          );
      // The router's redirect handles navigation once auth state changes.
    } catch (e) {
      HapticFeedback.heavyImpact();
      // Inline, next to the form, rather than a snackbar that slides away before
      // it has been read. A failed sign-in is something you act on.
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
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
              'We\'ll email you a link to set a new one.',
              style: ctx.text.bodyMedium
                  ?.copyWith(color: ctx.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.alternate_email),
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
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
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
    return Scaffold(
      // A crimson bloom top-left. Costs nothing, and it is the difference
      // between "warm canvas" and "dead beige".
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.bloom(AppColors.crimson)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ContentWidth(
              max: 440,
              // Genuinely centred: a sign-in form is one of the few layouts that
              // SHOULD sit in the middle of the viewport.
              centerVertically: true,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Wordmark(),
                    const SizedBox(height: Gap.xxl),

                    Text(
                      'Welcome back',
                      style: context.text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Sign in to see your conclaves and your table.',
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Gap.xl),

                    TextFormField(
                      controller: _identifier,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email or phone',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your email or phone'
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
                        prefixIcon: const Icon(Icons.lock_outline),
                        // Nearly every modern sign-in has this, and typing a
                        // password blind on a phone is how people lock
                        // themselves out.
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onFieldSubmitted: (_) => _login(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: Gap.sm),
                      _ErrorNote(message: _error!),
                    ],

                    const SizedBox(height: Gap.lg),
                    PrimaryButton(
                      label: 'Sign in',
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _login,
                    ),

                    const SizedBox(height: Gap.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: context.text.bodyMedium
                              ?.copyWith(color: context.scheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Register'),
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
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.scheme.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(Icons.groups_rounded,
              size: 24, color: context.scheme.onPrimaryContainer),
        ),
        const SizedBox(width: Gap.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BNI 121 Conclave',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Structured 1-to-1 networking',
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

/// An inline error that stays put until it's dealt with.
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
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: c.onDangerContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall
                    ?.copyWith(color: c.onDangerContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
