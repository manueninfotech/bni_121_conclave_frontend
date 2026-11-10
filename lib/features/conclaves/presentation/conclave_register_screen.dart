import 'package:flutter/material.dart';
import '../../../core/widgets/app_spinner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/conclave_calendar.dart';
import '../../../core/theme/tokens.dart';
import '../../active_conclave/data/notification_service.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../../profile/data/profile_repository.dart';
import '../data/conclave_repository.dart';
import '../domain/conclave_model.dart';
import 'payment_sheet.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';
import 'package:conclave_1_2_1/core/widgets/app_dialog.dart';

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

class _ConclaveRegisterScreenState
    extends ConsumerState<ConclaveRegisterScreen> {
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
        Analytics.conclaveRegister(widget.conclaveId, paid: true);
        Analytics.paymentCompleted(widget.conclaveId, pd.registrationFee);
        _onRegistered(conclave);
      }
      return;
    }

    // Free conclave: register in one tap, as before.
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(conclaveRepositoryProvider)
          .registerForConclave(widget.conclaveId);
      Analytics.conclaveRegister(widget.conclaveId, paid: false);

      if (!mounted) return;
      _onRegistered(conclave);
    } on RegistrationConflict catch (e) {
      // A clash is a decision the user has to understand, not a passing message
      // — and it cannot be undone by unregistering elsewhere.
      if (mounted) {
        await showAppNotice(
          context,
          icon: CoolIcons.calendarClose,
          title: 'Clashes with another conclave',
          message: e.message,
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

  /// Commit the registration SUCCESS to the UI immediately — navigate to the
  /// conclaves list and confirm — then run the calendar offer as a non-blocking
  /// follow-up. The hard rule: a member who has just paid must SEE that they're
  /// registered right away. The calendar step opens the native editor and leaves
  /// the app, and if the success navigation waited on it the member came back to
  /// the "Confirm registration" screen and feared the payment had failed. So
  /// success never waits on the calendar.
  void _onRegistered(Conclave conclave) {
    // No-UI side effects: subscribe to round alerts + schedule the app reminder.
    ref.read(notificationServiceProvider).subscribeAtRegistration(conclave.id);
    ConclaveCalendar.scheduleReminder(conclave);
    ref.invalidate(conclavesStreamProvider);

    // Success first: land on the conclaves list and confirm.
    context.go('/conclaves');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("You're registered.")));

    // Then offer the calendar OVER the conclaves list, via the root navigator so
    // it survives this screen being disposed by the navigation above.
    _offerCalendar(conclave);
  }

  /// Offers "add to calendar" after the success navigation has settled. Uses the
  /// app's root navigator context, so it no longer depends on this (now disposed)
  /// screen — and nothing it does can strand the member mid-flow.
  void _offerCalendar(Conclave conclave) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      final add = await showAppConfirm(
        ctx,
        icon: CoolIcons.calendarCheck,
        title: 'Add to your calendar?',
        message:
            "You're registered, and we'll remind you an hour before. Add the "
            'conclave to your calendar so it blocks your day too.',
        confirmLabel: 'Add to calendar',
        cancelLabel: 'Not now',
      );
      if (add == true) {
        try {
          await ConclaveCalendar.addToCalendar(conclave);
        } catch (_) {
          // Opening the native calendar editor can fail (no calendar app, denied
          // permission) — the reminder is already scheduled, so never block.
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conclaves = ref.watch(conclavesStreamProvider);
    final profile = ref.watch(myProfileProvider);

    final conclave = conclaves.asData?.value
        .where((c) => c.id == widget.conclaveId)
        .firstOrNull;
    final paid = conclave?.paymentDetails?.hasFee ?? false;

    return AppPage(
      title: 'Register',
      action: conclave == null
          ? null
          : AppPrimaryButton(
              label: paid
                  ? 'Pay ₹${conclave.paymentDetails!.registrationFee} and register'
                  : 'Confirm registration',
              busy: _isSubmitting,
              onPressed: () => _confirm(conclave),
            ),
      body: conclaves.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this conclave.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(conclavesStreamProvider),
        ),
        data: (_) {
          // Never fall back to `conclaves.first` — registering someone for a
          // DIFFERENT conclave than the one they tapped would be unforgivable,
          // and unfixable, since registration can't be withdrawn.
          if (conclave == null) {
            return EmptyView(
              icon: CoolIcons.searchClose,
              title: 'Conclave not found',
              message: 'It may have been cancelled or removed.',
              action: FilledButton(
                onPressed: () => context.go('/conclaves'),
                child: const Text('Back to conclaves'),
              ),
            );
          }

          return ContentWidth(
            max: 520,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.lg,
                context.pagePadding,
                Gap.xl,
              ),
              children: [
                PageHeading(
                  title: conclave.name,
                  subtitle: 'Check the details, then confirm your seat.',
                ),
                const SectionLabel('Conclave'),
                SectionCard(
                  children: [
                    DetailRow(
                      icon: CoolIcons.calendar,
                      label: 'Date',
                      value: DateFormat(
                        'EEEE, d MMMM yyyy',
                      ).format(conclave.date),
                    ),
                    if (conclave.startTime != null)
                      DetailRow(
                        icon: CoolIcons.clock,
                        label: 'Starts',
                        value: DateFormat('h:mm a').format(conclave.startTime!),
                      ),
                    DetailRow(
                      icon: CoolIcons.mapPin,
                      label: 'Venue',
                      value: conclave.venueLocation,
                    ),
                    if (paid)
                      DetailRow(
                        icon: CoolIcons.banknote,
                        label: 'Registration fee',
                        value: '₹${conclave.paymentDetails!.registrationFee}',
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                profile.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Gap.xl),
                    child: Center(child: AppSpinner(size: 28)),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (p) => p == null
                      ? const SizedBox.shrink()
                      : _ProfileCheck(profile: p),
                ),
                const SizedBox(height: Gap.xl),
                const _Commitment(),
              ],
            ),
          );
        },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'You will be seated as',
          trailing: GestureDetector(
            onTap: () => context.push('/profile/edit'),
            child: Text(
              missing ? 'Set category' : 'Edit',
              style: context.text.labelLarge?.copyWith(
                color: kActionRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SectionCard(
          children: [
            DetailRow(
              icon: CoolIcons.user,
              label: 'Name',
              value: profile.name.isEmpty ? 'Not set' : profile.name,
            ),
            DetailRow(
              icon: CoolIcons.building2,
              label: 'Business',
              value: profile.businessName.isEmpty
                  ? 'Not set'
                  : profile.businessName,
            ),
            DetailRow(
              icon: CoolIcons.shapes,
              label: 'Business category',
              value: missing ? 'Not set, required' : profile.businessCategory,
              valueColor: missing ? context.colors.danger : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// The part people skim past and then complain about. Stated plainly, once.
class _Commitment extends StatelessWidget {
  const _Commitment();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.warningContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: CoolIcons.lock, color: c.onWarningContainer),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration is final',
                  style: context.text.titleSmall?.copyWith(
                    color: c.onWarningContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'You cannot withdraw once registered. The schedule seats and '
                  "pairs you, so an empty seat affects other people's tables. "
                  'You also cannot register for another conclave at the same time.',
                  style: context.text.bodySmall?.copyWith(
                    color: c.onWarningContainer,
                    height: 1.45,
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
