import '../../../core/json_helpers.dart';

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
        filename: asString(json, 'filename'),
        mimeType: asString(json, 'mime_type', fallback: 'image/jpeg'),
        sizeBytes: asInt(json, 'size_bytes'),
        url: json['url'] as String,
        cdnUrl: asStringOrNull(json, 'cdn_url'),
      );
}
