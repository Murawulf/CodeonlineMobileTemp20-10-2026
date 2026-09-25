import 'dart:convert';

import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/fallback_network_image.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

/// Détail d'une FICHE CARACTÉRISTIQUE (produit / service hors fiche produit).
///
/// Même organisation que l'écran fiche produit (ProductDetailsScreen) :
///   barre de recherche -> onglets [Fiche caractéristique | Producteur]
///   -> image(s) en premier (défilement, flèches, zoom au toucher)
///   -> lignes libellé FR/EN + AR avec la valeur centrée.
/// Un bandeau "FICHE CARACTÉRISTIQUE" indique clairement le type de fiche.
///
/// API : V1_fp/caracteristique_by_id?id_carac=..
/// Chaque image a deux URLs (url + url_alt) : FallbackNetworkImage essaie la
/// seconde si la première échoue, donc l'image s'affiche comme sur le web.
class CaracteristiqueDetailScreen extends StatefulWidget {
  final int idCarac;
  final String? initialSearchQuery;

  const CaracteristiqueDetailScreen({
    Key? key,
    required this.idCarac,
    this.initialSearchQuery,
  }) : super(key: key);

  @override
  State<CaracteristiqueDetailScreen> createState() =>
      _CaracteristiqueDetailScreenState();
}

class _CaracteristiqueDetailScreenState
    extends State<CaracteristiqueDetailScreen>
    with SingleTickerProviderStateMixin {
  String selectedLanguage = 'en';
  late Future<Map<String, dynamic>> _futureData;
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getLanguagePreference();
    _futureData = _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      _currentImageIndex = 0;
      _futureData = _fetchData();
    });
  }

  // ------------------------------------------------------------------
  // Images
  // ------------------------------------------------------------------

  /// Pairs (url, altUrl) of the IMAGE illustrations, in order.
  List<List<String>> _imagePairs(Map<String, dynamic> data) {
    final pairs = <List<String>>[];
    final ills = data['illustrations'];
    if (ills is List) {
      for (final raw in ills) {
        if (raw is! Map) continue;
        if ((raw['type'] ?? 'image').toString() == 'video') continue;
        final url = (raw['url'] ?? '').toString();
        final alt = (raw['url_alt'] ?? '').toString();
        if (url.isEmpty && alt.isEmpty) continue;
        pairs.add([url, alt]);
      }
    }
    return pairs;
  }

  void _showImagePopup(String url, String alt) {
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
                    child: FallbackNetworkImage(
                      url: url,
                      altUrl: alt,
                      fit: BoxFit.contain,
                      errorIconSize: 48,
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

  void _goToImage(int index, int count) {
    if (index < 0 || index >= count) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildGallery(List<List<String>> images) {
    if (images.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary, size: 44),
            const SizedBox(height: 8),
            Text(
              _fr ? 'Aucune image' : 'No image',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final count = images.length;
    final int index =
        _currentImageIndex < count ? _currentImageIndex : count - 1;

    return Column(
      children: [
        Row(
          children: [
            if (count > 1)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.primary,
                onPressed: index > 0 ? () => _goToImage(index - 1, count) : null,
              ),
            Expanded(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (context, i) {
                    final url = images[i][0];
                    final alt = images[i][1];
                    return GestureDetector(
                      onTap: () => _showImagePopup(url, alt),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // contain : l'image entière est toujours visible,
                          // jamais recadrée (comme la fiche produit).
                          FallbackNetworkImage(
                            url: url,
                            altUrl: alt,
                            fit: BoxFit.contain,
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
                    );
                  },
                ),
              ),
            ),
            if (count > 1)
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: AppColors.primary,
                onPressed: index < count - 1
                    ? () => _goToImage(index + 1, count)
                    : null,
              ),
          ],
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                final active = i == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
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

  // ------------------------------------------------------------------
  // Building blocks (same style as ProductDetailsScreen)
  // ------------------------------------------------------------------

  /// "FICHE CARACTÉRISTIQUE" banner so users know what kind of sheet it is.
  Widget _buildTypeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fr ? 'FICHE CARACTÉRISTIQUE' : 'CHARACTERISTIC SHEET',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Text(
            'بطاقة الخصائص',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Label (FR/EN) left + Arabic label right, value centered underneath -
  /// identical layout to buildLabelValueRow in ProductDetailsScreen.
  Widget _labelValueRow(String labelEn, String labelFr, String labelAr,
      String? value,
      {bool mono = false, Color? valueColor}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _fr ? labelFr : labelEn,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: Text(
                  labelAr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              value.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: valueColor ?? AppColors.textPrimary,
                fontFamily: mono ? 'monospace' : null,
                letterSpacing: mono ? 1.0 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String fr, String en, String ar) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fr ? fr : en,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            ar,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildElements(List<dynamic> elements) {
    final rows = <Widget>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final nom = (raw['nom'] ?? '').toString().trim();
      if (nom.isEmpty) continue;
      String value = (raw['defaultValue'] ?? '').toString().trim();
      if (value.isEmpty && raw['options'] is List) {
        value = (raw['options'] as List)
            .map((o) => o.toString().trim())
            .where((o) => o.isNotEmpty)
            .join(', ');
      }
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, color: AppColors.divider));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                nom,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                value.isNotEmpty ? value : '-',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _card(Column(children: rows));
  }

  Widget _buildVideos(int count) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(count, (i) {
        return Container(
          width: 100,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_outline,
                  color: AppColors.primary, size: 30),
              const SizedBox(height: 4),
              Text(
                _fr ? 'Vidéo ${i + 1}' : 'Video ${i + 1}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _pickDescription(Map<String, dynamic> carac) {
    String v(String k) => (carac[k] ?? '').toString().trim();
    if (_fr) {
      return v('description_fr').isNotEmpty
          ? v('description_fr')
          : v('description_en');
    }
    return v('description_en').isNotEmpty
        ? v('description_en')
        : v('description_fr');
  }

  // ------------------------------------------------------------------
  // Tabs
  // ------------------------------------------------------------------

  Widget _buildFicheTab(Map<String, dynamic> data) {
    final carac = Map<String, dynamic>.from(data['carac'] as Map);
    final elements =
        (data['elements'] is List) ? data['elements'] as List : <dynamic>[];
    final ills = (data['illustrations'] is List)
        ? data['illustrations'] as List
        : <dynamic>[];
    final videoCount = ills
        .where((m) => m is Map && (m['type'] ?? '').toString() == 'video')
        .length;
    final images = _imagePairs(data);

    final identification = (carac['identification'] ?? '').toString().trim();
    final description = _pickDescription(carac);
    final descriptionAr = (carac['description_ar'] ?? '').toString().trim();
    final hasElements = elements
        .any((e) => e is Map && (e['nom'] ?? '').toString().trim().isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) Image first
          _buildGallery(images),
          const SizedBox(height: 16),

          // 2) Type banner + name
          _buildTypeBanner(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              identification.isNotEmpty
                  ? identification
                  : (_fr ? 'Sans nom' : 'Unnamed'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3) Main information (same rows as the fiche produit)
          _labelValueRow('Brand', 'Marque', 'العلامة التجارية',
              (carac['brand'] ?? '').toString(),
              valueColor: AppColors.primary),
          _labelValueRow('Identifier code', 'Code identifiant',
              'الرمز التعريفي', (carac['code_identifiant'] ?? '').toString(),
              mono: true),
          _labelValueRow('Purpose', 'Utilité', 'الاستعمال',
              (carac['utilite'] ?? '').toString()),
          _labelValueRow('Launch date', 'Date de lancement', 'تاريخ الإطلاق',
              (carac['date_lancement'] ?? '').toString()),

          // 4) Description
          if (description.isNotEmpty || descriptionAr.isNotEmpty) ...[
            _sectionTitle('Description', 'Description', 'الوصف'),
            _card(Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: AppColors.textPrimary),
                    ),
                  if (description.isNotEmpty && descriptionAr.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                  if (descriptionAr.isNotEmpty)
                    Text(
                      descriptionAr,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 16,
                          height: 1.6,
                          color: AppColors.textPrimary),
                    ),
                ],
              ),
            )),
          ],

          // 5) Technical elements
          if (hasElements) ...[
            _sectionTitle(
                'Éléments techniques', 'Technical elements', 'الخصائص التقنية'),
            _buildElements(elements),
          ],

          // 6) Videos
          if (videoCount > 0) ...[
            _sectionTitle('Vidéos', 'Videos', 'فيديوهات'),
            _buildVideos(videoCount),
          ],
        ],
      ),
    );
  }

  Widget _buildProducerTab(Map<String, dynamic> data) {
    final carac = Map<String, dynamic>.from(data['carac'] as Map);
    final producer = (data['producer'] is Map)
        ? Map<String, dynamic>.from(data['producer'] as Map)
        : <String, dynamic>{};
    String p(String k) => (producer[k] ?? '').toString().trim();

    final company =
        p('companyName').isNotEmpty ? p('companyName') : (carac['entite_name'] ?? '').toString();
    final logo = p('logo');

    final rows = <Widget>[
      _labelValueRow('Company Name', 'Nom de l’entreprise', 'اسم الشركة', company,
          valueColor: AppColors.primary),
      _labelValueRow('GLN', 'Numéro GLN', 'الرقم التجاري', p('gln')),
      _labelValueRow('Address', 'Adresse', 'الـعنـوان', p('adresse')),
      _labelValueRow('Phone', 'Téléphone', 'الـهـاتـف', p('telephone')),
      _labelValueRow('Email', 'E-mail', 'الـبريد الالكـترونـي', p('email')),
      _labelValueRow('Website', 'Site Web', 'موقع الويب', p('site')),
    ];

    final hasAny = company.trim().isNotEmpty ||
        ['gln', 'adresse', 'telephone', 'email', 'site']
            .any((k) => p(k).isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logo.isNotEmpty)
            Center(
              child: Container(
                width: 90,
                height: 90,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: FallbackNetworkImage(
                  url: logo,
                  fit: BoxFit.contain,
                  errorIcon: Icons.business,
                  errorIconSize: 36,
                ),
              ),
            ),
          if (hasAny)
            ...rows
          else
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  _fr
                      ? 'Aucune information producteur'
                      : 'No producer information',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
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
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ...List.generate(6, (index) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomSearchBar(
                initialText: widget.initialSearchQuery,
                selectedLanguage: selectedLanguage,
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              labelStyle:
                  const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: _fr ? 'Fiche caractéristique' : 'Characteristic sheet'),
                Tab(text: _fr ? 'Producteur' : 'Producer'),
              ],
            ),
            Expanded(
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
                            _fr
                                ? 'Fiche caractéristique non trouvée'
                                : 'Characteristic sheet not found',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18, color: AppColors.danger),
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
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _KeepAlive(child: _buildFicheTab(data)),
                      _KeepAlive(child: _buildProducerTab(data)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab alive when switching tabs, so the image carousel keeps its
/// position (and does not reload) when coming back to the first tab.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
