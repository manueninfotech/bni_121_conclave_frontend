import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conclave_repository.dart';
import '../data/payment_service.dart';
import '../domain/conclave_model.dart';

/// Runs the registration-fee flow for a paid conclave.
///
/// Returns `true` when the member is registered (paid online, or committed to an
/// offline transfer the admin will reconcile), `false`/`null` if they backed out.
/// The caller handles navigation and the success message.
///
/// Online payment degrades gracefully: if the backend can't mint an order
/// (keys unset, endpoint not deployed) the sheet drops to offline only, so a
/// member is never dead-ended at a pay wall the server can't service.
Future<bool?> showRegistrationPaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Conclave conclave,
  String? prefillEmail,
  String? prefillContact,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _PaymentSheet(
        conclave: conclave,
        prefillEmail: prefillEmail,
        prefillContact: prefillContact,
      ),
    ),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final Conclave conclave;
  final String? prefillEmail;
  final String? prefillContact;

  const _PaymentSheet({
    required this.conclave,
    this.prefillEmail,
    this.prefillContact,
  });

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  bool _busy = false;
  String? _error;

  /// Flips to true when online payment isn't available (server can't mint an
  /// order) — then only the offline path is offered.
  bool _offlineOnly = false;
  bool _showOfflineDetails = false;
  final _utr = TextEditingController();

  PaymentDetails get _pd => widget.conclave.paymentDetails!;

  @override
  void dispose() {
    _utr.dispose();
    super.dispose();
  }

  Future<void> _payOnline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payments = ref.read(paymentServiceProvider);
      final order = await payments.createOrder(widget.conclave.id);
      final proof = await payments.openCheckout(
        order: order,
        conclaveName: widget.conclave.name,
        prefillEmail: widget.prefillEmail,
        prefillContact: widget.prefillContact,
      );
      await ref
          .read(conclaveRepositoryProvider)
          .registerForConclave(widget.conclave.id, payment: proof.toJson());
      ref.invalidate(conclavesStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } on PaymentUnavailable {
      // The server can't take the payment online (keys unset, or the endpoint
      // isn't deployed yet). Show a clean message — never the raw backend text,
      // which can be a technical 404/503 — and drop to the offline path.
      if (mounted) {
        setState(() {
          _offlineOnly = true;
          _showOfflineDetails = _pd.hasOfflineDetails;
          _error = _pd.hasOfflineDetails
              ? "Online payment isn't available right now. You can pay offline below."
              : "Online payment isn't available right now. Please contact the organiser.";
        });
      }
    } on PaymentCancelled catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on RegistrationConflict catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payOffline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(conclaveRepositoryProvider).registerForConclave(
            widget.conclave.id,
            payment: const {'method': 'offline'},
            utrNumber: _utr.text,
          );
      ref.invalidate(conclavesStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } on RegistrationConflict catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fee = _pd.registrationFee;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registration fee', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('₹$fee',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              widget.conclave.name,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              _ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],

            if (_showOfflineDetails)
              _OfflineDetails(pd: _pd, utrController: _utr)
            else ...[
              if (!_offlineOnly) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _payOnline,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(_busy ? 'Please wait…' : 'Pay ₹$fee securely'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Card, UPI, netbanking — powered by Razorpay.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or'),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
              ],
              if (_pd.hasOfflineDetails)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _showOfflineDetails = true),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Pay offline (UPI / bank transfer)'),
                )
              else if (_offlineOnly)
                // No online path AND no offline details configured — nothing the
                // member can do from here.
                Text(
                  'Online payment is unavailable and no offline payment details '
                  'have been set. Please contact the organiser.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
            ],

            if (_showOfflineDetails) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _payOffline,
                child: Text(_busy ? 'Registering…' : "I've paid — register"),
              ),
              const SizedBox(height: 4),
              Text(
                'Your registration stays pending until the organiser confirms the '
                'transfer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfflineDetails extends StatelessWidget {
  final PaymentDetails pd;
  final TextEditingController utrController;

  const _OfflineDetails({required this.pd, required this.utrController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pd.upiQrImageUrl != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                pd.upiQrImageUrl!,
                height: 180,
                width: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (pd.upiId != null)
          _CopyRow(label: 'UPI ID', value: pd.upiId!),
        if (pd.accountHolderName != null)
          _CopyRow(label: 'Account name', value: pd.accountHolderName!),
        if (pd.accountNumber != null)
          _CopyRow(label: 'Account no.', value: pd.accountNumber!),
        if (pd.ifscCode != null) _CopyRow(label: 'IFSC', value: pd.ifscCode!),
        if (pd.bankName != null) _CopyRow(label: 'Bank', value: pd.bankName!),
        const SizedBox(height: 12),
        TextField(
          controller: utrController,
          decoration: InputDecoration(
            labelText: 'Payment reference / UTR (optional)',
            helperText: 'Helps the organiser match your transfer.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: theme.colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
