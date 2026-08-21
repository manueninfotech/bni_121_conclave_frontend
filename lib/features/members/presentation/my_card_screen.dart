import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_repository.dart';

/// The member's own digital business card as a scannable vCard QR — the
/// consented way to hand your contact to someone you just met: they point their
/// camera at it and their phone offers to save you. Nobody else's details are
/// exposed; you only ever share your own.
class MyCardScreen extends ConsumerWidget {
  const MyCardScreen({super.key});

  String _vcard(UserProfile p) {
    // Escape the few characters vCard treats specially.
    String e(String s) =>
        s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;');
    return [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${e(p.name)}',
      'N:;${e(p.name)};;;',
      if (p.phone.isNotEmpty) 'TEL;TYPE=CELL:${e(p.phone)}',
      if (p.email.isNotEmpty) 'EMAIL:${e(p.email)}',
      if (p.businessName.isNotEmpty) 'ORG:${e(p.businessName)}',
      if (p.businessCategory.isNotEmpty) 'TITLE:${e(p.businessCategory)}',
      'END:VCARD',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My card')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your card.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (p) {
          if (p == null) {
            return const EmptyView(
              icon: Icons.badge_outlined,
              title: 'No profile yet',
            );
          }
          return Center(
            child: SingleChildScrollView(
              padding: context.pageInsets,
              child: ContentWidth(
                max: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(name: p.name, photoUrl: p.photoUrl, radius: 40),
                    const SizedBox(height: Gap.md),
                    Text(
                      p.name.isEmpty ? 'Unnamed' : p.name,
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (p.businessName.isNotEmpty)
                      Text(
                        p.businessName,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: Gap.xl),
                    Container(
                      padding: const EdgeInsets.all(Gap.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: context.colors.hairline),
                      ),
                      child: QrImageView(
                        data: _vcard(p),
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        // Fixed dark modules — the QR must stay black-on-white to
                        // scan reliably regardless of theme.
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Text(
                      'Point a camera at this to save my contact.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
