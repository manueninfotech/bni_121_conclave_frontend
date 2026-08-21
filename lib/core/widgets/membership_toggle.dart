import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// BNI / Non-BNI selector. No default — nothing is selected until the member
/// picks, so registration can require an explicit choice.
class MembershipToggle extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final String label;

  const MembershipToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Are you a BNI member?',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Gap.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'BNI',
                label: Text('BNI member'),
                icon: Icon(Icons.verified_outlined),
              ),
              ButtonSegment(
                value: 'Non-BNI',
                label: Text('Non-BNI'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            // An empty set = "nothing chosen yet".
            selected: value == null ? <String>{} : {value!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onChanged(s.first);
            },
          ),
        ),
      ],
    );
  }
}
