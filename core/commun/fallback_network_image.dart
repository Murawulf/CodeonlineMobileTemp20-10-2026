import 'package:cached_network_image/cached_network_image.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Network image with an automatic second chance.
///
/// Fiche caractéristique images come from the API with two URLs:
///  - [url]    : same path as the fiche produit images (/images/products/..)
///  - [altUrl] : the web admin's own media route (/api/caracteristiques/media/..)
/// If [url] fails to load, [altUrl] is tried before showing the error icon,
/// so an image that displays on the web also displays in the app.
class FallbackNetworkImage extends StatelessWidget {
  final String url;
  final String? altUrl;
  final BoxFit fit;
  final double errorIconSize;
  final IconData errorIcon;

  const FallbackNetworkImage({
    super.key,
    required this.url,
    this.altUrl,
    this.fit = BoxFit.contain,
    this.errorIconSize = 36,
    this.errorIcon = Icons.image_not_supported,
  });

  Widget _loading() => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );

  Widget _error() => Center(
        child: Icon(errorIcon,
            color: AppColors.textSecondary, size: errorIconSize),
      );

  @override
  Widget build(BuildContext context) {
    final alt = (altUrl ?? '').trim();
    final hasAlt = alt.isNotEmpty && alt != url;

    if (url.trim().isEmpty) {
      if (!hasAlt) return _error();
      return CachedNetworkImage(
        imageUrl: alt,
        fit: fit,
        placeholder: (_, __) => _loading(),
        errorWidget: (_, __, ___) => _error(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => _loading(),
      errorWidget: (_, __, ___) => hasAlt
          ? CachedNetworkImage(
              imageUrl: alt,
              fit: fit,
              placeholder: (_, __) => _loading(),
              errorWidget: (_, __, ___) => _error(),
            )
          : _error(),
    );
  }
}
