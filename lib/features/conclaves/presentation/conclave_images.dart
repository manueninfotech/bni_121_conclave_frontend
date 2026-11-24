import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/live_conclave_source.dart';
import '../../../core/links/shared_links.dart';
import '../../../core/theme/cool_icons.dart';
import '../../../core/theme/tokens.dart';
import '../domain/conclave_image.dart';

/// A conclave's cover and flyers, live: the conclave's stream carries them,
/// so a cover or flyer the organiser changes in the admin panel shows here
/// within seconds, without a reload.
typedef ConclaveMedia = ({ConclaveImage? cover, List<ConclaveImage> flyers});

final conclaveMediaProvider = StreamProvider.autoDispose
    .family<ConclaveMedia, String>((ref, id) {
      return watchConclaveDoc(id).map(
        (doc) => (
          cover: ConclaveImage.fromJson(doc['coverImage']),
          flyers: ConclaveImage.listFrom(doc['flyers']),
        ),
      );
    });

/// A network image that fills its box, with a quiet placeholder while it
/// loads and if it fails (no broken-image icon on a member's screen).
class _NetImage extends StatelessWidget {
  final ConclaveImage image;
  final BoxFit fit;
  const _NetImage({required this.image, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final bg = context.scheme.surfaceContainerHighest;
    return Image.network(
      image.src,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
        opacity: sync || frame != null ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: child,
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : ColoredBox(color: bg),
      errorBuilder: (context, _, _) => ColoredBox(
        color: bg,
        child: Center(
          child: Icon(CoolIcons.image, color: context.scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The cover, 16:9 with rounded corners.
class ConclaveCover extends StatelessWidget {
  final ConclaveImage image;
  final double radius;
  final double aspectRatio;
  const ConclaveCover({
    super.key,
    required this.image,
    this.radius = 20,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _NetImage(image: image),
      ),
    );
  }
}

/// Flyers as a swipeable row of portrait cards; tap one to see it full screen.
class FlyerStrip extends StatelessWidget {
  final List<ConclaveImage> flyers;
  final String conclaveId;
  final String conclaveName;
  const FlyerStrip({
    super.key,
    required this.flyers,
    required this.conclaveId,
    required this.conclaveName,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: flyers.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: 'Flyer ${i + 1} of ${flyers.length}',
          child: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => FlyerViewer(
                  flyers: flyers,
                  initial: i,
                  conclaveId: conclaveId,
                  conclaveName: conclaveName,
                ),
              ),
            ),
            child: Hero(
              tag: 'flyer-${flyers[i].id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _NetImage(image: flyers[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen flyers: swipe between them, pinch to zoom, share the image.
class FlyerViewer extends StatefulWidget {
  final List<ConclaveImage> flyers;
  final int initial;
  final String conclaveId;
  final String conclaveName;
  const FlyerViewer({
    super.key,
    required this.flyers,
    required this.initial,
    required this.conclaveId,
    required this.conclaveName,
  });

  @override
  State<FlyerViewer> createState() => _FlyerViewerState();
}

class _FlyerViewerState extends State<FlyerViewer> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _page = widget.initial;
  bool _sharing = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final f = widget.flyers[_page];
    final box = buttonContext.findRenderObject() as RenderBox?;
    try {
      final res = await Dio().get<List<int>>(
        f.src,
        options: Options(responseType: ResponseType.bytes),
      );
      final type =
          res.headers.value('content-type')?.split(';').first ?? 'image/jpeg';
      final ext = type.endsWith('png')
          ? 'png'
          : type.endsWith('webp')
          ? 'webp'
          : 'jpg';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(res.data ?? const []),
              mimeType: type,
              name: 'flyer-${_page + 1}.$ext',
            ),
          ],
          text:
              '${widget.conclaveName}: ${SharedLinks.conclave(widget.conclaveId)}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share this flyer. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.flyers.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: 'flyer-${widget.flyers[i].id}',
                  child: _NetImage(
                    image: widget.flyers[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CoolIcons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    n > 1 ? '${_page + 1} of $n' : '',
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Builder(
                  builder: (bc) => IconButton(
                    tooltip: 'Share',
                    onPressed: _sharing ? null : () => _share(bc),
                    icon: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(CoolIcons.share, color: Colors.white),
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
