import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/phone.dart';
import '../theme/tokens.dart';

/// A phone input with a country picker.
///
/// The picker exists so nobody has to type "+91" — and so that the number stays
/// unambiguous once BNI is running conclaves outside India. Ten digits is a
/// valid Indian mobile AND a valid US number; the app must not have to guess
/// which, because the number is the account identity.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final String? label;
  final bool autofocus;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.label,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CountrySheet(selected: widget.country),
    );
    if (picked != null) widget.onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-()]')),
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        labelText: widget.label ?? 'Phone number',
        hintText: widget.country.nationalLength == 10 ? '98765 43210' : null,
        // The prefix is a button, not decoration — tapping the country code is
        // the first thing anyone tries.
        prefixIcon: _CountryButton(
          country: widget.country,
          onTap: _pickCountry,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (v) => Phone.validate(widget.country, v ?? ''),
    );
  }
}

class _CountryButton extends StatelessWidget {
  final Country country;
  final VoidCallback onTap;

  const _CountryButton({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: Gap.sm),
            Text(
              '+${country.dial}',
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: context.scheme.onSurfaceVariant,
            ),
            // A divider, so the code reads as a separate control from the number
            // rather than as part of it.
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.only(left: Gap.sm, right: Gap.md),
              color: context.colors.hairline,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  final Country selected;
  const _CountrySheet({required this.selected});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? countries
        : countries
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.dial.contains(q) ||
                c.code.toLowerCase() == q)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Country',
                  style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Gap.lg),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search country or code',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No match for "$_query"',
                      style: ctx.text.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: Gap.xl),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final c = results[i];
                      final isSelected = c.code == widget.selected.code;
                      return ListTile(
                        onTap: () => Navigator.pop(context, c),
                        leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(
                          c.name,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+${c.dial}',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: Gap.sm),
                              Icon(Icons.check_rounded,
                                  size: 20, color: context.scheme.primary),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Email / phone chooser.
///
/// The app used to sniff which one you meant from a single field. That is where
/// the bug came from: "9515409973" was read as a phone, turned into a different
/// synthetic address than the one it was registered under, and the user was told
/// their credentials were wrong. Asking is unambiguous, and it lets the phone
/// path have a country code at all.
enum LoginMethod { phone, email }

class MethodToggle extends StatelessWidget {
  final LoginMethod value;
  final ValueChanged<LoginMethod> onChanged;

  const MethodToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Row(
        children: [
          for (final m in LoginMethod.values)
            Expanded(
              child: _Segment(
                label: m == LoginMethod.phone ? 'Phone' : 'Email',
                icon: m == LoginMethod.phone
                    ? Icons.phone_iphone_rounded
                    : Icons.alternate_email_rounded,
                selected: value == m,
                onTap: () => onChanged(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.scheme.surface : context.scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.curve,
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? context.scheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: Gap.sm),
            Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
