import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'payment_sheet.dart';

/// Confirm registration.
///
/// Two things this screen has to get across, because both are irreversible:
///
///  - Registration cannot be withdrawn. The schedule seats and pairs you, so
///    vanishing later leaves a hole in other people's tables.
///  - Your business category decides who you sit with, and it is frozen into the
///    conclave when the schedule is generated. This is the last comfortable
///    moment to fix it, so the screen shows it and links to the editor.
class ConclaveRegisterScreen extends ConsumerStatefulWidget {
  final String conclaveId;

  const ConclaveRegisterScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveRegisterScreen> createState() =>
      _ConclaveRegisterScreenState();
}

class _ConclaveRegisterScreenState extends ConsumerState<ConclaveRegisterScreen> {
  bool _isSubmitting = false;

  Future<void> _confirm(Conclave conclave) async {
    // Paid conclave: hand off to the payment sheet, which owns the online/offline
    // flow and the /register call. It pops `true` once the member is registered.
    final pd = conclave.paymentDetails;
    if (pd != null && pd.hasFee) {
      final profile = ref.read(myProfileProvider).asData?.value;
      final registered = await showRegistrationPaymentSheet(
        context: context,
        ref: ref,
        conclave: conclave,
        prefillEmail: profile?.email,
        prefillContact: profile?.phone,
      );
      if (registered == true && mounted) {
        context.go('/conclaves');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're registered.")),
        );
      }
      return;
    }

    // Free conclave: register in one tap, as before.
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(conclaveRepositoryProvider)
          .registerForConclave(widget.conclaveId);
      ref.invalidate(conclavesStreamProvider);

      if (!mounted) return;
      context.go('/conclaves');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're registered.")),
      );
    } on RegistrationConflict catch (e) {
      // A clash is a decision the user has to understand, not a passing message
      // — and it cannot be undone by unregistering elsewhere.
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.event_busy_outlined, color: ctx.colors.danger),
            title: const Text('Clashes with another conclave'),
            content: Text(e.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conclaves = ref.watch(conclavesStreamProvider);
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm registration')),
      body: conclaves.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this conclave.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(conclavesStreamProvider),
        ),
        data: (all) {
          // Never fall back to `conclaves.first` — registering someone for a
          // DIFFERENT conclave than the one they tapped would be unforgivable,
          // and unfixable, since registration can't be withdrawn.
          final conclave = all.where((c) => c.id == widget.conclaveId).firstOrNull;

          if (conclave == null) {
            return EmptyView(
              icon: Icons.search_off_rounded,
              title: 'Conclave not found',
              message: 'It may have been cancelled or removed.',
              action: FilledButton(
                onPressed: () => context.go('/conclaves'),
                child: const Text('Back to conclaves'),
              ),
            );
          }

          return ContentWidth(
            child: ListView(
              padding: context.pageInsets,
              children: [
                Text(
                  conclave.name,
                  style: context.text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Gap.lg),

                _Card(
                  children: [
                    InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Venue',
                      value: conclave.venueLocation,
                    ),
                    InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: DateFormat('EEEE, MMMM d, yyyy').format(conclave.date),
                    ),
                    if (conclave.startTime != null)
                      InfoRow(
                        icon: Icons.schedule,
                        label: 'Starts',
                        value: DateFormat('h:mm a').format(conclave.startTime!),
                      ),
                    if (conclave.paymentDetails?.hasFee ?? false)
                      InfoRow(
                        icon: Icons.payments_outlined,
                        label: 'Fee',
                        value: '₹${conclave.paymentDetails!.registrationFee}',
                      ),
                  ],
                ),

                const SizedBox(height: Gap.md),
                profile.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (p) => p == null
                      ? const SizedBox.shrink()
                      : _ProfileCheck(profile: p),
                ),

                const SizedBox(height: Gap.md),
                _Commitment(),

                const SizedBox(height: Gap.xl),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : () => _confirm(conclave),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text((conclave.paymentDetails?.hasFee ?? false)
                            ? 'Continue to payment'
                            : 'Confirm registration'),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                TextButton(
                  onPressed: _isSubmitting ? null : () => context.pop(),
                  child: const Text('Not now'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Card({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// What we're about to seat you as. The category is the whole basis of the
/// seating, so it gets checked here rather than discovered at the venue.
class _ProfileCheck extends StatelessWidget {
  final UserProfile profile;

  const _ProfileCheck({required this.profile});

  @override
  Widget build(BuildContext context) {
    final missing = profile.businessCategory.isEmpty;

    return _Card(
      title: 'You will be seated as',
      children: [
        InfoRow(
          icon: Icons.person_outline,
          label: 'Name',
          value: profile.name.isEmpty ? 'Not set' : profile.name,
        ),
        InfoRow(
          icon: Icons.business_outlined,
          label: 'Business',
          value: profile.businessName.isEmpty ? 'Not set' : profile.businessName,
        ),
        InfoRow(
          icon: Icons.category_outlined,
          label: 'Business category',
          value: missing ? 'Not set — required' : profile.businessCategory,
        ),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(missing ? 'Set your category' : 'Wrong? Edit profile'),
          ),
        ),
      ],
    );
  }
}

/// The part people skim past and then complain about. Stated plainly, once.
class _Commitment extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: c.onWarningContainer),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration is final',
                  style: context.text.titleSmall?.copyWith(
                    color: c.onWarningContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'You cannot withdraw once registered — the schedule seats and '
                  'pairs you, so an empty seat affects other people\'s tables. '
                  'You also cannot register for another conclave at the same time.',
                  style: context.text.bodySmall
                      ?.copyWith(color: c.onWarningContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
