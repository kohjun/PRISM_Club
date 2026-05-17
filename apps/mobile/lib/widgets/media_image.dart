import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/config.dart' show apiBaseUrl;
import '../features/media/data/media_dto.dart';

/// Renders an uploaded image asset. Handles loading + error states.
/// `url` may be a relative path (/uploads/...) — resolved against AppConfig.apiBase.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.asset,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final MediaAssetDto asset;
  final double? height;
  final double? width;
  final BoxFit fit;

  String _absoluteUrl() {
    final raw = asset.url;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // Strip trailing /v1 from apiBase so the /uploads path resolves correctly.
    final base = apiBaseUrl.replaceAll(RegExp(r'/v1/?$'), '');
    return '$base$raw';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _absoluteUrl(),
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height ?? 160,
            width: width,
            color: PrismColors.soft,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (ctx, _, _) => Container(
          height: height ?? 160,
          width: width,
          color: PrismColors.soft,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined,
              color: PrismColors.muted, size: 36),
        ),
      ),
    );
  }
}
