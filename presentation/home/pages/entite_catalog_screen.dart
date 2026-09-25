import 'dart:convert';
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/search/pages/CategoryDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

/// Entity-scoped browse screen.
///
/// Reached by tapping an entity's logo/"Voir tous les produits" tile in the
/// home showcase pager. Shows this entity's own brand(s), each with its list
/// of GPC categories - exactly the same brand -> category layout a manual
/// brand search already produces (see search.dart), just pre-scoped to this
/// entity instead of typed in. Tapping a category opens the SAME, already
/// working CategoryDetailsScreen every search result already uses.
///
/// Talks ONLY to the mobile PHP API (V1_fp, AppConfig.apiBase):
///   1. entite_brands?id_entite=..        (new - this entity's own brands)
///   2. fiche_produit_marque_categorie_by_brand?brand=..  (existing, reused)
/// Never talks to the web admin's server.js.
class EntiteCatalogScreen extends StatefulWidget {
  final int idEntite;
  final String entiteName;
  final String? logoUrl;

  const EntiteCatalogScreen({
    Key? key,
    required this.idEntite,
    required this.entiteName,
    this.logoUrl,
  }) : super(key: key);

  @override
  _EntiteCatalogScreenState createState() => _EntiteCatalogScreenState();
}

class _EntiteCatalogScreenState extends State<EntiteCatalogScreen> {
  String selectedLanguage = 'en';

  bool isLoading = true;
  // One entry per brand this entity sells: {brand, categories: [{name, name_ar, code}]}
  // - the exact same shape search.dart already renders.
  List<Map<String, dynamic>> brandEntries = [];

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'en';
    });
    _loadCatalogue();
  }

  Map<String, String> get _langHeaders => {
        'x-lang': selectedLanguage == 'fr' ? 'fr-FR' : 'en-US',
      };

  Future<void> _loadCatalogue() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Step 1: which brand(s) does this entity actually sell?
      final brandsUri = Uri.parse(
        '${AppConfig.apiBase}//api_fp/V1_fp/entite_brands?id_entite=${widget.idEntite}',
      );
      final brandsResponse = await http.get(brandsUri, headers: _langHeaders);

      List<String> brands = [];
      if (brandsResponse.statusCode == 200) {
        final data = json.decode(brandsResponse.body);
        brands = List<String>.from((data['brands'] ?? []).map((b) => b.toString()));
      }

      if (brands.isEmpty) {
        setState(() {
          brandEntries = [];
          isLoading = false;
        });
        return;
      }

      // Step 2: for each brand, fetch its categories via the SAME endpoint
      // a manual brand search already uses - fiche_produit_marque_categorie_by_brand
      // already returns [{brand, categories:[...]}, ...], so merge every
      // brand's result into one flat list, same shape search.dart renders.
      final List<Map<String, dynamic>> entries = [];
      for (final brand in brands) {
        try {
          final uri = Uri.parse(
            '${AppConfig.apiBase}//api_fp/V1_fp/fiche_produit_marque_categorie_by_brand'
            '?brand=${Uri.encodeQueryComponent(brand)}',
          );
          final response = await http.get(uri, headers: _langHeaders);
          if (response.statusCode != 200) continue;

          final decoded = json.decode(response.body);
          final list = decoded is List ? decoded : [decoded];
          for (final item in list) {
            if (item is Map) {
              entries.add(Map<String, dynamic>.from(item));
            }
          }
        } catch (e) {
          print('Failed to fetch categories for brand "$brand": $e');
        }
      }

      setState(() {
        brandEntries = entries;
        isLoading = false;
      });
    } catch (e) {
      print('Failed to load entite catalogue: $e');
      setState(() {
        brandEntries = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      backgroundColor: Colors.white,
      // No entity header anymore (no logo/initials tile + raison sociale
      // name row) - straight to the brand/category list, per request. The
      // entity's name still reaches this screen (widget.entiteName) in
      // case it's needed again later, it's just not rendered here now.
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? _buildLoadingShimmer()
            : (brandEntries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: brandEntries.length,
                    itemBuilder: (context, index) {
                      return _buildBrandCard(brandEntries[index]);
                    },
                  )),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        selectedLanguage == 'fr'
            ? 'Aucun produit disponible pour le moment.'
            : 'No products available yet.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Shimmer.fromColors(
            baseColor: AppColors.surfaceAlt,
            highlightColor: Colors.white,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }

  // One card per brand: brand name header + its list of category rows -
  // same layout/behavior as search.dart's results list, just scoped to this
  // entity's own brand(s) instead of a typed search query.
  Widget _buildBrandCard(Map<String, dynamic> entry) {
    final brand = (entry['brand'] ?? '').toString();
    final categories = List.from(entry['categories'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            brand.isNotEmpty ? brand : '-',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          for (var category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  final code = category['code']?.toString() ?? '';
                  if (code.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryDetailsScreen(
                        brand: brand,
                        categoryCode: code,
                        categoryName: (category['name'] ?? '').toString(),
                      ),
                    ),
                  );
                },
                child: Container(
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
                          (category['name'] ?? '').toString().isNotEmpty
                              ? category['name'].toString()
                              : (selectedLanguage == 'fr'
                                  ? 'Sans catégorie'
                                  : 'No category'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
