class MediaAssetDto {
  const MediaAssetDto({
    required this.id,
    required this.kind,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.url,
    this.cdnUrl,
  });

  final String id;
  final String kind; // IMAGE
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String url; // relative path like /uploads/<uuid>.png
  /// P1.4: canonical client-facing URL. Falls back to `url` when the
  /// server hasn't been wired with a CDN yet.
  final String? cdnUrl;

  /// Best display URL the client should use.
  String get displayUrl => cdnUrl ?? url;

  factory MediaAssetDto.fromJson(Map<String, dynamic> json) => MediaAssetDto(
        id: json['id'] as String,
        kind: json['kind'] as String,
        filename: json['filename'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? 'image/jpeg',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        url: json['url'] as String,
        cdnUrl: json['cdn_url'] as String?,
      );
}
