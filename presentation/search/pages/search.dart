import 'dart:async'; // debounce + timeouts
import 'dart:convert';

import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/fallback_network_image.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/search/pages/CaracteristiqueDetailScreen.dart';
import 'package:codeonline_info/presentation/search/pages/CategoryDetailsScreen.dart';
import 'package:codeonline_info/presentation/search/pages/ProductDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One result block on the search screen: a brand, with
///  - its GPC categories (fiches produit), exactly as before, and/or
///  - its fiches caractéristique (approved "fiche permanente" only).
/// A brand that has NO fiche produit but has fiches caractéristique still
/// gets its own block, so a brand search always shows what exists.
class _BrandGroup {
  final String brand; // '' = fiches caractéristique without a brand
  final List<dynamic> categories = [];
  final List<Map<String, dynamic>> caracs = [];

  _BrandGroup(this.brand);
}

class SearchPage extends StatefulWidget {
  final String searchQuery;

  const SearchPage({super.key, required this.searchQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String selectedLanguage = 'en';
  bool isLoading = false;
  List<_BrandGroup> searchResults = [];
  Timer? debounceTimer;
  final Map<String, List<_BrandGroup>> cache = {};
  late String currentQuery;
  int _requestSeq = 0; // ignores responses of outdated queries

  bool get _fr => selectedLanguage == 'fr';

  @override
  void initState() {
    super.initState();
    currentQuery = widget.searchQuery.trim();
    _init();
  }

  Future<void> _init() async {
    await _getLanguagePreference();
    if (currentQuery.length >= 3) {
      _fetchSearchResults(currentQuery);
    }
  }

  Future<void> _getLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  Map<String, String> get _langHeaders => {
        'x-lang': _fr ? 'fr-FR' : 'en-US',
      };

  // ---------------------------------------------------------------------
  // Fiches produit: brand -> categories (same endpoint / shape as before).
  // ---------------------------------------------------------------------
  Future<List<dynamic>> _fetchBrandResults(String query) async {
    try {
      final url =
          '${AppConfig.apiBase}//api_fp/V1_fp/fiche_produit_marque_categorie_by_brand?brand=${Uri.encodeQueryComponent(query)}';
      final response = await http
          .get(Uri.parse(url), headers: _langHeaders)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
      }
    } catch (e) {
      debugPrint('Brand search error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------
  // Fiches caractéristique matching the same text (brand first).
  // Fails silently: it can never break the fiche produit search.
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchCaracteristiqueResults(
      String query) async {
    try {
      final url =
          '${AppConfig.apiBase}//api_fp/V1_fp/caracteristiques_search?q=${Uri.encodeQueryComponent(query)}';
      final response = await http
          .get(Uri.parse(url), headers: _langHeaders)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['caracteristiques'] is List) {
          return (decoded['caracteristiques'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Caracteristique search error: $e');
    }
    return [];
  }

  /// Exact code_identifiant lookup (619 + entité + numéro). Returns the
  /// id_carac of a visible fiche, or null.
  Future<int?> _findCaracteristiqueByCode(String code) async {
    try {
      final url =
          '${AppConfig.apiBase}//api_fp/V1_fp/caracteristique_by_code?code=${Uri.encodeQueryComponent(code)}';
      final response = await http
          .get(Uri.parse(url), headers: _langHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['id_carac'] != null) {
          final id = int.tryParse(decoded['id_carac'].toString());
          if (id != null && id > 0) return id;
        }
      }
    } catch (e) {
      debugPrint('Caracteristique code lookup error: $e');
    }
    return null;
  }

  /// Merges both result sets into brand blocks (case-insensitive brand).
  List<_BrandGroup> _merge(
      List<dynamic> brandResults, List<Map<String, dynamic>> caracs) {
    final groups = <String, _BrandGroup>{};
    final order = <String>[];

    String keyOf(String b) => b.trim().toLowerCase();

    for (final raw in brandResults) {
      if (raw is! Map) continue;
      final brand = (raw['brand'] ?? '').toString().trim();
      if (brand.isEmpty) continue;
      final key = keyOf(brand);
      final group = groups.putIfAbsent(key, () {
        order.add(key);
        return _BrandGroup(brand);
      });
      final cats = raw['categories'];
      if (cats is List) group.categories.addAll(cats);
    }

    const noBrandKey = '\u0000no-brand';
    for (final carac in caracs) {
      final brand = (carac['brand'] ?? '').toString().trim();
      final key = brand.isEmpty ? noBrandKey : keyOf(brand);
      final group = groups.putIfAbsent(key, () {
        order.add(key);
        return _BrandGroup(brand);
      });
      group.caracs.add(carac);
    }

    // Keep "no brand" fiches at the very end (order otherwise preserved).
    final ordered = <String>[
      ...order.where((k) => k != noBrandKey),
      ...order.where((k) => k == noBrandKey),
    ];
    return ordered
        .map((k) => groups[k]!)
        .where((g) => g.categories.isNotEmpty || g.caracs.isNotEmpty)
        .toList();
  }

  Future<void> _fetchSearchResults(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 3) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    final seq = ++_requestSeq;

    // Purely numeric (8-14 digits) = GTIN or code identifiant.
    // A fiche caractéristique with exactly this code opens directly;
    // otherwise the normal GTIN product screen opens, as before.
    if (RegExp(r'^\d{8,14}$').hasMatch(query)) {
      setState(() => isLoading = true);
      final idCarac = await _findCaracteristiqueByCode(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() => isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => idCarac != null
              ? CaracteristiqueDetailScreen(
                  idCarac: idCarac, initialSearchQuery: query)
              : ProductDetailScreen(gtin: query, initialSearchQuery: query),
        ),
      );
      return;
    }

    final cacheKey = '${selectedLanguage}|${query.toLowerCase()}';
    if (cache.containsKey(cacheKey)) {
      setState(() {
        searchResults = cache[cacheKey]!;
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final brandFuture = _fetchBrandResults(query);
      final caracFuture = _fetchCaracteristiqueResults(query);
      final brandResults = await brandFuture;
      final caracResults = await caracFuture;
      if (!mounted || seq != _requestSeq) return;
      final merged = _merge(brandResults, caracResults);
      setState(() {
        searchResults = merged;
        cache[cacheKey] = merged;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onSearchQueryChanged(String query) {
    currentQuery = query;
    debounceTimer?.cancel();
    if (query.trim().length < 3) {
      _requestSeq++; // cancel any in-flight result
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }
    debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSearchResults(query);
    });
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: CustomSearchBar(
              initialText: widget.searchQuery,
              onChanged: _onSearchQueryChanged,
              selectedLanguage: selectedLanguage,
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _fr ? 'Aucun résultat' : 'No data found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) =>
                    _buildBrandCard(searchResults[index]),
              ),
            ),
        ],
      ),
    );
  }

  // One card per brand: categories (fiches produit, unchanged behaviour)
  // then the brand's fiches caractéristique.
  Widget _buildBrandCard(_BrandGroup group) {
    final title = group.brand.isNotEmpty
        ? group.brand
        : (_fr ? 'Autres fiches caractéristique' : 'Other characteristic sheets');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in group.categories)
              if (category is Map) _buildCategoryTile(group.brand, category),
            if (group.caracs.isNotEmpty) ...[
              if (group.categories.isNotEmpty) const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  _fr ? 'Fiches caractéristique' : 'Characteristic sheets',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final carac in group.caracs) _buildCaracteristiqueTile(carac),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String brand, Map category) {
    final name = (category['name'] ?? '').toString();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDetailsScreen(
              brand: brand,
              categoryCode: (category['code'] ?? '').toString(),
              categoryName: name,
              searchQuery: currentQuery,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name.isNotEmpty ? name : 'No category',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // Same look as a product row in CategoryDetailsScreen (image + title +
  // subtitle), inside the brand card.
  Widget _buildCaracteristiqueTile(Map<String, dynamic> item) {
    final identification = (item['identification'] ?? '').toString();
    final entiteName = (item['entite_name'] ?? '').toString();
    final code = (item['code_identifiant'] ?? '').toString();
    final thumbnail = (item['thumbnail'] ?? '').toString();
    final thumbnailAlt = (item['thumbnail_alt'] ?? '').toString();
    final idCarac = int.tryParse((item['id_carac'] ?? '').toString());

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: idCarac == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CaracteristiqueDetailScreen(
                          idCarac: idCarac, initialSearchQuery: currentQuery),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: (thumbnail.isNotEmpty || thumbnailAlt.isNotEmpty)
                  ? FallbackNetworkImage(
                      url: thumbnail,
                      altUrl: thumbnailAlt,
                      fit: BoxFit.cover,
                      errorIcon: Icons.inventory_2_outlined,
                      errorIconSize: 24,
                    )
                  : const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Small type chip so the user knows it is a
                  // fiche caractéristique (not a fiche produit).
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fr ? 'Fiche caractéristique' : 'Characteristic sheet',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  Text(
                    identification.isNotEmpty
                        ? identification
                        : (_fr ? 'Sans nom' : 'Unnamed'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (code.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        (_fr ? 'Code : ' : 'Code: ') + code,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  if (entiteName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entiteName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
