import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/profile_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The member's own digital business card as a scannable vCard QR — the
/// consented way to hand your contact to someone you just met: they point their
/// camera at it and their phone offers to save you. Nobody else's details are
/// exposed; you only ever share your own.
class MyCardScreen extends ConsumerWidget {
  const MyCardScreen({super.key});

  String _vcard(UserProfile p) {
    // Escape the few characters vCard treats specially.
    String e(String s) => s
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
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

    return AppPage(
      title: 'My card',
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
              icon: CoolIcons.idBadge,
              title: 'No profile yet',
            );
          }
          return Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.lg,
                context.pagePadding,
                Gap.xl,
              ),
              child: ContentWidth(
                max: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The card itself: who you are, then the code.
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.xl,
                        Gap.xl,
                        Gap.xl,
                        Gap.lg,
                      ),
                      decoration: pagePanel(context, radius: 28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                name: p.name,
                                photoUrl: p.photoUrl,
                                radius: 28,
                              ),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name.isEmpty ? 'Unnamed' : p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (p.businessName.isNotEmpty)
                                      Text(
                                        p.businessName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.text.bodyMedium
                                            ?.copyWith(
                                              color: context
                                                  .scheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (p.businessCategory.isNotEmpty) ...[
                            const SizedBox(height: Gap.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kActionRed.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  p.businessCategory,
                                  style: context.text.labelMedium?.copyWith(
                                    color: kActionRed,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: Gap.lg),
                          Divider(height: 1, color: context.colors.hairline),
                          const SizedBox(height: Gap.lg),
                          LayoutBuilder(
                            builder: (context, c) => QrImageView(
                              data: _vcard(p),
                              version: QrVersions.auto,
                              size: c.maxWidth.clamp(180, 260),
                              backgroundColor: Colors.white,
                              // Fixed dark modules: the QR must stay black-on-white
                              // to scan reliably regardless of theme.
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
                          const SizedBox(height: Gap.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CoolIcons.camera,
                                size: 16,
                                color: context.scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: Gap.xs),
                              Flexible(
                                child: Text(
                                  'Scan with any camera to save my contact',
                                  textAlign: TextAlign.center,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    const PageNote(
                      'Only your own details are in this code: name, phone, email, '
                      'business and category.',
                      icon: CoolIcons.shieldCheck,
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
