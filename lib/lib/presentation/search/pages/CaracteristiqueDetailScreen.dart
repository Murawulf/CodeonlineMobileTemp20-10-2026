import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

/// Detail screen for one "fiche caractéristique" (product/service that does
/// not fit a normal fiche produit - see the web admin's Caracteristiques
/// page). Opened from the SAME search screen as the fiches produit
/// (search.dart): from a brand block, or directly when its generated code
/// identifiant (619 + entité + numéro) is typed/scanned.
///
/// Talks ONLY to the mobile PHP API (V1_fp):
///   caracteristique_by_id?id_carac=..
///
/// Images are stored and served exactly like fiche produit images
/// (/images/products/..., resolved to absolute URLs by the API), shown in
/// the same swipeable gallery + tap-to-zoom style as ProductDetailsScreen.
/// No new package dependency.
class CaracteristiqueDetailScreen extends StatefulWidget {
  final int idCarac;

  const CaracteristiqueDetailScreen({Key? key, required this.idCarac})
      : super(key: key);

  @override
  State<CaracteristiqueDetailScreen> createState() =>
      _CaracteristiqueDetailScreenState();
}

class _CaracteristiqueDetailScreenState
    extends State<CaracteristiqueDetailScreen> {
  String selectedLanguage = 'en';
  late Future<Map<String, dynamic>> _futureData;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
    _futureData = _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _getLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  bool get _fr => selectedLanguage == 'fr';

  Future<Map<String, dynamic>> _fetchData() async {
    final uri = Uri.parse(
      '${AppConfig.apiBase}//api_fp/V1_fp/caracteristique_by_id?id_carac=${widget.idCarac}',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['carac'] is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw Exception('not_found');
    }
    throw Exception('Failed to load data');
  }

  void _retry() {
    setState(() {
      _futureData = _fetchData();
    });
  }

  void _showImagePopup(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textSecondary,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          ...List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: double.infinity,
                height: 20,
                color: AppColors.surfaceAlt,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // Main gallery (images only) - same behaviour as the fiche produit screen:
  // swipe, dots, tap to zoom.
  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Icon(Icons.inventory_2_outlined,
              color: AppColors.primary, size: 48),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              final url = images[index];
              return GestureDetector(
                onTap: () => _showImagePopup(context, url),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.image_not_supported,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.zoom_in,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // Videos: safe non-interactive tiles (no video package needed).
  Widget _buildVideos(List<Map<String, dynamic>> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_outline,
                    color: AppColors.primary, size: 32),
                const SizedBox(height: 6),
                Text(
                  _fr ? 'Vidéo' : 'Video',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildElements(List<dynamic> elements) {
    final rows = <Widget>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final el = Map<String, dynamic>.from(raw);
      final nom = (el['nom'] ?? '').toString().trim();
      if (nom.isEmpty) continue;
      String value = (el['defaultValue'] ?? '').toString().trim();
      if (value.isEmpty && el['options'] is List) {
        value = (el['options'] as List)
            .map((o) => o.toString())
            .where((o) => o.isNotEmpty)
            .join(', ');
      }
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                nom,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  String _pickDescription(Map<String, dynamic> carac) {
    String v(String k) => (carac[k] ?? '').toString().trim();
    if (_fr) {
      return v('description_fr').isNotEmpty ? v('description_fr') : v('description_en');
    }
    return v('description_en').isNotEmpty ? v('description_en') : v('description_fr');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _futureData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildShimmer(),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fr ? 'Fiche non trouvée' : 'Sheet not found',
                      style:
                          const TextStyle(fontSize: 18, color: AppColors.danger),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _retry,
                      child: Text(_fr ? 'Réessayer' : 'Retry'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final carac = Map<String, dynamic>.from(data['carac'] as Map);
            final elements = (data['elements'] is List)
                ? data['elements'] as List
                : <dynamic>[];
            final illustrations = (data['illustrations'] is List)
                ? (data['illustrations'] as List)
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList()
                : <Map<String, dynamic>>[];

            final images = illustrations
                .where((m) =>
                    (m['type'] ?? 'image').toString() != 'video' &&
                    (m['url'] ?? '').toString().isNotEmpty)
                .map((m) => m['url'].toString())
                .toList();
            final videos = illustrations
                .where((m) => (m['type'] ?? '').toString() == 'video')
                .toList();

            final identification = (carac['identification'] ?? '').toString();
            final description = _pickDescription(carac);
            final utilite = (carac['utilite'] ?? '').toString().trim();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGallery(images),
                const SizedBox(height: 16),
                Text(
                  identification.isNotEmpty
                      ? identification
                      : (_fr ? 'Sans nom' : 'Unnamed'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(_fr ? 'Marque' : 'Brand',
                          (carac['brand'] ?? '').toString()),
                      _kv(_fr ? 'Code identifiant' : 'Identifier code',
                          (carac['code_identifiant'] ?? '').toString()),
                      _kv(_fr ? 'Entreprise' : 'Company',
                          (carac['entite_name'] ?? '').toString()),
                      _kv(_fr ? 'Date de lancement' : 'Launch date',
                          (carac['date_lancement'] ?? '').toString()),
                    ],
                  ),
                ),
                if (utilite.isNotEmpty) ...[
                  _sectionLabel(_fr ? 'Utilité' : 'Purpose'),
                  Text(
                    utilite,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  _sectionLabel(_fr ? 'Description' : 'Description'),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                  ),
                ],
                if ((carac['description_ar'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      carac['description_ar'].toString().trim(),
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                    ),
                  ),
                ],
                if (elements.isNotEmpty) ...[
                  _sectionLabel(
                      _fr ? 'Éléments techniques' : 'Technical elements'),
                  _buildElements(elements),
                ],
                if (videos.isNotEmpty) ...[
                  _sectionLabel(_fr ? 'Vidéos' : 'Videos'),
                  _buildVideos(videos),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
