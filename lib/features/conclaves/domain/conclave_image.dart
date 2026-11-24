import '../../../core/config/api_config.dart';

/// A conclave's cover image or one of its flyers, set in the admin panel.
class ConclaveImage {
  final String id;

  /// Server link (`/api/files/...`); see [src].
  final String url;
  final String name;

  const ConclaveImage({
    required this.id,
    required this.url,
    required this.name,
  });

  /// Full address for Image.network.
  String get src => ApiConfig.resolveUrl(url) ?? url;

  static ConclaveImage? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    return ConclaveImage(
      id: (json['id'] ?? url).toString(),
      url: url,
      name: (json['name'] ?? '').toString(),
    );
  }

  static List<ConclaveImage> listFrom(Object? json) => [
    for (final e in (json is List ? json : const []))
      ?ConclaveImage.fromJson(e),
  ];

  @override
  bool operator ==(Object other) =>
      other is ConclaveImage && other.id == id && other.url == url;

  @override
  int get hashCode => Object.hash(id, url);
}
