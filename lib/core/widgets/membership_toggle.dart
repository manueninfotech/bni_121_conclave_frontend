import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pill_switch.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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
        PillSwitch<String>(
          value: value,
          onChanged: onChanged,
          options: const [
            PillOption('BNI', 'BNI member', CoolIcons.wavyCheck),
            PillOption('Non-BNI', 'Non-BNI', CoolIcons.user),
          ],
        ),
      ],
    );
  }
}
