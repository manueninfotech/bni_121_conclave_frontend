import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/phone.dart';
import '../../../core/theme/cool_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/phone_field.dart';
import '../../../core/widgets/responsive.dart';
import '../../active_conclave/presentation/round/round_timer.dart' show kDeckBottom;
import '../data/auth_repository.dart';

/// Forgot password, self-serve.
///
///  - Phone account: we text a 6-digit code; with it and a new password the
///    member resets the password themselves and lands signed in.
///  - Email account: we email a reset link (never confirming whether the
///    address is registered).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Which tab to open on — matches the login screen's method.
  final LoginMethod initialMethod;
  const ForgotPasswordScreen({super.key, this.initialMethod = LoginMethod.phone});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { enter, code, emailSent }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late LoginMethod _method = widget.initialMethod;
  _Step _step = _Step.enter;
  Country _country = defaultCountry;
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;
  String? _verificationId;

  @override
  void dispose() {
    for (final c in [_phone, _email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _e164 => Phone.toE164(_country, _phone.text);

  void _fail(String msg) {
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _error = msg);
  }

  Future<void> _sendCode() async {
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 6) {
      return _fail('Enter the phone number you registered with.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authRepositoryProvider).verifyPhone(
          phone: _e164,
          onCodeSent: (id) {
            if (!mounted) return;
            setState(() {
              _verificationId = id;
              _busy = false;
              _step = _Step.code;
            });
          },
          onError: (msg) {
            if (!mounted) return;
            setState(() => _busy = false);
            _fail(msg);
          },
        );
  }

  Future<void> _reset() async {
    final code = _code.text.trim();
    if (code.length != 6) return _fail('Enter the 6-digit code from the SMS.');
    if (_password.text.length < 6) return _fail('Use at least 6 characters for the new password.');
    if (_password.text != _confirm.text) return _fail('The two passwords do not match.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPasswordWithPhone(
            verificationId: _verificationId!,
            smsCode: code,
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password updated. You are signed in.')));
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendEmail() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return _fail('Enter the email address you registered with.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) setState(() => _step = _Step.emailSent);
    } catch (e) {
      _fail(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step == _Step.code) {
      setState(() {
        _step = _Step.enter;
        _error = null;
      });
      return;
    }
    context.canPop() ? context.pop() : context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.enter => (
          'Reset your password',
          _method == LoginMethod.phone
              ? "We'll text a code to your registered number."
              : "We'll email you a link to set a new one.",
        ),
      _Step.code => ('Enter the code', 'We sent a 6-digit code to $_e164. Then choose a new password.'),
      _Step.emailSent => (
          'Check your inbox',
          'If ${_email.text.trim()} has an account, a reset link is on its way. Open it on this phone.',
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            children: [
              const SizedBox(height: Gap.sm),
              Row(children: [
                Transform.translate(
                  offset: const Offset(-Gap.sm, 0),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: _busy ? null : _back,
                    icon: const Icon(CoolIcons.arrowLeft),
                  ),
                ),
              ]),
              const SizedBox(height: Gap.md),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _step == _Step.emailSent ? CoolIcons.mailCheck : CoolIcons.key,
                  color: AppColors.brandRed,
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text(title,
                  style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: Gap.sm),
              Text(subtitle,
                  style: context.text.bodyLarge?.copyWith(color: context.scheme.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: Gap.xl),
              ..._form(context),
              if (_error != null) ...[
                const SizedBox(height: Gap.md),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(CoolIcons.circleWarning, size: 18, color: context.colors.danger),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(_error!,
                        style: context.text.bodyMedium?.copyWith(color: context.colors.danger)),
                  ),
                ]),
              ],
              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    switch (_step) {
      case _Step.enter:
        return [
          MethodToggle(
            value: _method,
            onChanged: (m) => setState(() {
              _method = m;
              _error = null;
            }),
          ),
          const SizedBox(height: Gap.lg),
          if (_method == LoginMethod.phone)
            PhoneField(
              controller: _phone,
              country: _country,
              autofocus: true,
              onCountryChanged: (c) => setState(() => _country = c),
              textInputAction: TextInputAction.done,
              onSubmitted: _sendCode,
            )
          else
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendEmail(),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(CoolIcons.mention),
              ),
            ),
          const SizedBox(height: Gap.xl),
          _Primary(
            label: _method == LoginMethod.phone ? 'Send code' : 'Send reset link',
            busy: _busy,
            onTap: _method == LoginMethod.phone ? _sendCode : _sendEmail,
          ),
        ];
      case _Step.code:
        return [
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: context.text.titleLarge?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _password,
            obscureText: _hide,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(CoolIcons.lock),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide ? CoolIcons.eye : CoolIcons.eyeOff),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _confirm,
            obscureText: _hide,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _reset(),
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(CoolIcons.lock),
            ),
          ),
          const SizedBox(height: Gap.xl),
          _Primary(label: 'Reset password', busy: _busy, onTap: _reset),
          const SizedBox(height: Gap.sm),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _sendCode,
              child: const Text('Send the code again'),
            ),
          ),
        ];
      case _Step.emailSent:
        return [
          _Primary(label: 'Back to sign in', busy: false, onTap: () => context.go('/login')),
        ];
    }
  }
}

class _Primary extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const _Primary({required this.label, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kDeckBottom,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: 16),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}
