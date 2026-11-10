import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/tokens.dart';

/// The installed app's version, e.g. "1.4.0 (33)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber.trim();
  return build.isEmpty ? info.version : '${info.version} ($build)';
});

/// Quiet sign-off at the bottom of Profile: who builds the app, and exactly
/// which version is installed (useful when someone reports a problem).
class PoweredByFooter extends ConsumerWidget {
  const PoweredByFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.scheme.onSurfaceVariant;
    final version = ref.watch(appVersionProvider).value;
    return Column(
      children: [
        Text(
          'POWERED BY',
          style: context.text.labelSmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: Gap.sm),
        // The logo spells out "Manuen Infotech"; no separate name line.
        Image.asset(
          'assets/images/manuen_logo.png',
          height: 30,
          semanticLabel: 'Manuen Infotech',
        ),
        if (version != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            '1-2-1 Connect  ·  Version $version',
            style: context.text.labelSmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
