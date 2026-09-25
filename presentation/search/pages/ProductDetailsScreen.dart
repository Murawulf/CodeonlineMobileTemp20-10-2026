import 'package:cached_network_image/cached_network_image.dart';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';

class ProductDetailScreen extends StatefulWidget {
  final String gtin;
  final String? initialSearchQuery;

  ProductDetailScreen({required this.gtin, this.initialSearchQuery});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _productData;
  late TabController _tabController;
  int _currentImageIndex = 0;
  List<String> _images = [];
  late PageController _pageController;
  Map<String, ImageProvider> _imageCache = {}; // Cache for preloaded images

  String selectedLanguage = 'en'; // Default language

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _getLanguagePreference();
    _productData = fetchProductData();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  Future<Map<String, dynamic>> fetchProductData() async {
    final url =
        '${AppConfig.apiBase}//api_fp/v1_fp/fiche_produit_by_gtin?gtin=${widget.gtin}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['images'] != null) {
        _images = List<String>.from(data['images']);
        // Preload images
        for (String imageUrl in _images) {
          _imageCache[imageUrl] = Image.network(imageUrl).image;
        }
      }
      return data;
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _nextImage() {
    if (_currentImageIndex < (_images.length - 1)) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget buildLabelValueRow(String labelEn, String labelAr, String labelFr,
      String? brand, String? subBrand) {
    // Check if both brand and subBrand are empty or null
    if ((brand == null || brand.isEmpty) &&
        (subBrand == null || subBrand.isEmpty)) {
      return SizedBox.shrink(); // Return nothing if both are null or empty
    }

    // Determine the dynamic label (English or French) based on the selected language
    String dynamicLabel;
    switch (selectedLanguage) {
      case 'fr':
        dynamicLabel = labelFr; // Use French label
        break;
      default:
        dynamicLabel = labelEn; // Default to English
    }

    // Combine brand and subBrand into a single value
    String combinedValue = brand ?? "";
    if (subBrand != null && subBrand.isNotEmpty) {
      combinedValue +=
          "\n$subBrand"; // Add subBrand under brand if it's not empty
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Labels: Dynamic Label and Arabic Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dynamicLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textDirection: TextDirection.ltr, // Dynamic label is LTR
                ),
              ),
              Expanded(
                child: Text(
                  labelAr,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl, // Arabic is RTL
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          // Centered Combined Value
          Center(
            child: Text(
              combinedValue,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.5, // Line height for better readability
              ),
              textAlign: TextAlign.center, // Center-align the text
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePopup(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 1.2,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true, // Allow panning
                    minScale: 1.0, // Minimum zoom scale
                    maxScale: 5.0, // Maximum zoom scale
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: Icon(Icons.close, color: AppColors.primary),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildLabelValueRowV2(
    String labelEn,
    String labelFr,
    String labelAr,
    String? brand,
  ) {
    // Check if brand is null or empty
    if (brand == null || brand.isEmpty) {
      return SizedBox.shrink(); // Return nothing if brand is null or empty
    }

    // Determine which label to display based on selectedLanguage
    String selectedLabel = selectedLanguage == 'fr' ? labelFr : labelEn;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedLabel,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                labelAr,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Center(
            child: Text(
              brand,
              style: TextStyle(fontSize: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(8, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              width: double.infinity,
              height: 20,
              color: AppColors.surfaceAlt,
            ),
          );
        }),
      ),
    );
  }

  // No longer wraps itself in its own SingleChildScrollView - it was nested
  // inside another scroll view above it (the product-tab's own
  // SingleChildScrollView), and that double nesting inside a fixed-height
  // parent was what made the detail rows look cut off instead of laying
  // out normally. A plain Column here lets that single outer scroll view
  // size and scroll everything together.
  Widget buildDataDisplay(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabelValueRow('Brand', 'العلامة التجارية', 'Marque',
            data['brand'], data['subBrand']),
        buildLabelValueRow('Sales typology', 'نوعية التسويق',
            'Typologie des ventes', data['codeCader'], null),
        buildLabelValueRow(
            'GTIN', 'الرقم التجاري العالمي', 'GTIN', data['gtin'], null),
        buildLabelValueRow('Product Name', 'اسم المنتوج', 'Nom du produit',
            data['productName'], null),
        buildLabelValueRow('Country of Origin', 'بلد المنشأ',
            'Pays d\'origine', data['countryOfOrigin'], null),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // No outer SingleChildScrollView anymore - the whole page (search bar +
    // tabs + tab content) fits in one viewport, no scrolling. The tab
    // content area is now an Expanded (fills whatever's left below the
    // search bar and tab strip) instead of a height guessed from
    // MediaQuery, and the Product tab's own inner scroll view is gone too -
    // between that and the smaller, non-cropped image below, everything
    // fits without needing to scroll to read it.
    return Scaffold(
      appBar: CustomAppBar(),
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
            SizedBox(height: 12),
            Expanded(
              child: DefaultTabController(
                length: 2, // 2 tabs: Product and Producer
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(
                          text: selectedLanguage == 'fr' ? 'Produit' : 'Product',
                        ),
                        Tab(
                          text: selectedLanguage == 'fr'
                              ? 'Producteur'
                              : 'Producer',
                        ),
                      ],
                      labelColor: AppColors.primary, // Set the active tab text color
                      labelStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
                      unselectedLabelColor:
                          AppColors.textSecondary, // Set the inactive tab text color
                    ),
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                      future: _productData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: buildShimmerPlaceholder(),
                          );
                        } else if (snapshot.hasError) {
                          // If error occurs, show the error message
                          String errorMessage = selectedLanguage == 'fr'
                              ? 'Produit non trouvé'
                              : 'Product not found';
                          return Center(
                            child: Text(
                              errorMessage,
                              style: TextStyle(fontSize: 20, color: AppColors.danger),
                            ),
                          );
                        } else if (!snapshot.hasData || snapshot.data == null) {
                          return Center(
                            child: Text(
                              'No data available.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        } else {
                          var data = snapshot.data!;
                          if (_images.isEmpty && data['images'] != null) {
                            _images = List<String>.from(data['images']);
                          }

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                // No inner SingleChildScrollView anymore -
                                // this Column is bounded by the TabBarView's
                                // own Expanded box above, and everything in
                                // it (a small image row + a handful of
                                // short detail rows) fits inside that box
                                // without needing to scroll.
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (_images.length > 1)
                                            IconButton(
                                              icon: Icon(Icons.arrow_back),
                                              onPressed: _previousImage,
                                            ),
                                          Expanded(
                                            child: Container(
                                              // Smaller than the original
                                              // (300 -> 150), but BoxFit.contain
                                              // below means the WHOLE image is
                                              // always visible - never cropped -
                                              // just letterboxed if it isn't a
                                              // perfect square. Tap it to see it
                                              // full-size instead (_showImagePopup,
                                              // unchanged).
                                              height: 150,
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceAlt,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: PageView.builder(
                                                controller: _pageController,
                                                onPageChanged: (index) {
                                                  setState(() {
                                                    _currentImageIndex = index;
                                                  });
                                                },
                                                itemCount: _images.length,
                                                itemBuilder: (context, index) {
                                                  return GestureDetector(
                                                    onTap: () =>
                                                        _showImagePopup(context,
                                                            _images[index]),
                                                    child: Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        CachedNetworkImage(
                                                          imageUrl: _images[
                                                              index], // Assuming `_images[index]` contains the URL of the image.
                                                          // contain (not cover) - the whole
                                                          // image is always visible, never
                                                          // cropped, just letterboxed on the
                                                          // surfaceAlt background if it isn't
                                                          // a perfect square.
                                                          fit: BoxFit.contain,
                                                          placeholder: (context,
                                                                  url) =>
                                                              CircularProgressIndicator(
                                                            color: AppColors.accent,
                                                          ), // Optional: Placeholder while loading.
                                                          errorWidget: (context,
                                                                  url, error) =>
                                                              Icon(
                                                            Icons.image_not_supported,
                                                            color: AppColors.textSecondary,
                                                          ), // Optional: Error icon when the image can't load.
                                                        ),
                                                        // Small "tap to enlarge" hint badge -
                                                        // the image is small now, this makes
                                                        // it obvious it's tappable.
                                                        Positioned(
                                                          right: 6,
                                                          bottom: 6,
                                                          child: Container(
                                                            width: 22,
                                                            height: 22,
                                                            decoration: BoxDecoration(
                                                              color: AppColors.accent,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(Icons.zoom_in,
                                                                color: Colors.white,
                                                                size: 14),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          if (_images.length > 1)
                                            IconButton(
                                              icon: Icon(Icons.arrow_forward),
                                              onPressed: _nextImage,
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 30),
                                        child: buildDataDisplay(data),
                                      ),
                                    ],
                                  ),
                              ),
                              // Producer Tab
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (data['companyName']?.isNotEmpty ??
                                        false)
                                      buildLabelValueRowV2(
                                        'Company Name',
                                        'Nom de l’entreprise',
                                        'اسم الشركة',
                                        data['companyName'],
                                      ),
                                    if (data['gln']?.isNotEmpty ?? false)
                                      buildLabelValueRowV2(
                                        'GLN',
                                        'Numéro GLN',
                                        'الرقم التجاري',
                                        data['gln'],
                                      ),
                                    if (data['adresse']?.isNotEmpty ?? false)
                                      buildLabelValueRowV2(
                                        'Address',
                                        'Adresse',
                                        'الـعنـوان',
                                        data['adresse'],
                                      ),
                                    if (data['telephone']?.isNotEmpty ?? false)
                                      buildLabelValueRowV2(
                                        'Phone',
                                        'Téléphone',
                                        'الـهـاتـف',
                                        data['telephone'],
                                      ),
                                    if (data['email']?.isNotEmpty ?? false)
                                      buildLabelValueRowV2(
                                        'Email',
                                        'E-mail',
                                        'الـبريد الالكـترونـي',
                                        data['email'],
                                      ),
                                    if (data['site']?.isNotEmpty ?? false)
                                      buildLabelValueRowV2(
                                        'Website',
                                        'Site Web',
                                        'موقع الويب',
                                        data['site'],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
