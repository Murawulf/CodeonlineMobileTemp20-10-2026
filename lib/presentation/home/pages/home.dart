import 'dart:async';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:cached_network_image/cached_network_image.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/assets/app_images.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/notifs/notif.dart';
import 'package:codeonline_info/presentation/home/pages/entite_catalog_screen.dart';
import 'package:codeonline_info/presentation/home/pages/help_screen.dart';
import 'package:codeonline_info/presentation/search/pages/ProductDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // How many products to show per entity in the product-grid showcase page.
  static const int kShowcaseProductsPerEntity = 4;

  // Product-grid showcase geometry - kept as named constants (instead of a
  // guessed fixed pixel height) so the pager and its loading shimmer always
  // size themselves to fit exactly what they render, on any screen width.
  static const double kShowcaseCardAspectRatio = 0.78;
  static const double kShowcaseGridSpacing = 12;

  // The whole home page has to fit on one screen - no scrolling to see the
  // banner. Search bar + notification button keep their small natural
  // height, the sponsor banner keeps its exact fixed height untouched, and
  // the showcase grid is the one piece that shrinks: this derives the 2x2
  // grid's childAspectRatio from BOTH the width and the height actually
  // left over for it, so the cards exactly fill whatever space remains -
  // smaller on a short screen, bigger on a tall one - with no clipping. No
  // header row above the grid anymore (no entity name text), so there's no
  // reserve to subtract - the grid gets the whole box.
  double _gridChildAspectRatio(double maxWidth, double maxHeight) {
    final cardWidth = (maxWidth - kShowcaseGridSpacing) / 2;
    final cardHeight = (maxHeight - kShowcaseGridSpacing) / 2;
    if (cardWidth <= 0 || cardHeight <= 0) {
      // Degenerate constraints (shouldn't normally happen) - fall back to
      // the old fixed ratio rather than dividing by zero/negative.
      return kShowcaseCardAspectRatio;
    }
    return cardWidth / cardHeight;
  }

  List<Map<String, dynamic>> menuItems = [];
  List<String> sponsorImages = [];
  String selectedLanguage = 'en';
  bool isLoading = true; // Loading state
  bool hasError = false; // Error state
  PageController _pageController =
      PageController(); // Create the PageController (sponsor carousel)
  Timer? _timer;
  bool isDropdownOpen = false; // Tracks if the dropdown is open

  // ---------------------------------------------------------------------
  // Showcase state.
  //
  // Each entry in `showcaseEntities` is one entity that currently has at
  // least one admin-approved highlighted product:
  //   { id_entite, name, logo, products: [ {id, gtin, brand, productName, images: [...]}, ... ] }
  // This comes from the web backend's admin-approval workflow (an entity
  // flags products -> a platform admin at entité 999/111 approves them),
  // NOT from any hardcoded brand. Served by the SAME PHP API (V1_fp,
  // AppConfig.apiBase) every other call on this screen already uses — see
  // fetchHighlightedShowcase() below. It reads the `product_highlights`
  // table the web app writes to, straight from the shared database.
  //
  // One grid per entity: the first tile is that entity's logo/"Voir tous
  // les produits" (tap -> EntiteCatalogScreen), the remaining tiles (up to
  // 3) are its highlighted products (tap -> product detail).
  // ---------------------------------------------------------------------
  List<Map<String, dynamic>> showcaseEntities = [];
  bool isShowcaseLoading = true;

  final PageController _showcasePageController = PageController();
  int _showcasePageIndex = 0;

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
    _pageController = PageController();
    _startAutoScroll();
    fetchContent(); // Fetch content when screen loads
    fetchHighlightedShowcase(); // Fetch admin-approved highlighted products
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
    fetchContent(); // Fetch content when language preference is retrieved
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose();
    _showcasePageController.dispose();
    super.dispose();
  }

  // One shared timer drives auto-scroll (and looping back to the start once
  // it reaches the end - "re-scroll") for every swipeable pager on this
  // screen: the sponsor carousel AND the showcase grid. Each block below is
  // independent and self-guarded (checks hasClients + a non-empty source
  // list) so it's safe even before that pager's data has loaded yet, or
  // once it only has a single page.
  void _startAutoScroll() {
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      // Sponsor carousel.
      if (_pageController.hasClients && sponsorImages.isNotEmpty) {
        int nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        if (nextPage >= sponsorImages.length) {
          nextPage = 0; // Loop back to the first page
        }
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }

      // Showcase grid (entity/"voir tout" tile + its highlighted products).
      if (_showcasePageController.hasClients && showcaseEntities.isNotEmpty) {
        int nextPage = (_showcasePageController.page?.toInt() ?? 0) + 1;
        if (nextPage >= showcaseEntities.length) {
          nextPage = 0; // Loop back to the first entity
        }
        _showcasePageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // The old PDF-based help was replaced with an in-app, bilingual FAQ
  // screen (help_screen.dart) - no document to fetch or download, no
  // network call at all, nothing sent anywhere. Kept as a method (rather
  // than inlining the navigation at the call site) so the FAB's onPressed
  // stays a one-line reference, same as it always was.
  void _openHelpDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpScreen(),
      ),
    );
  }

  Future<void> fetchContent() async {
    setState(() {
      isLoading = true; // Start loading
      hasError = false; // Reset error state
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBase}//api_fp/V1_fp/sponsors'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Populate menu items based on the selected language
          menuItems = (data['menuPrincipal'] as List).map((item) {
            String text = '';
            String fallback = '';

            if (selectedLanguage == 'fr') {
              // If language is French, display French text and fallback to Arabic text
              text = item['fr'] ?? '';
              fallback = item['ar'] ?? 'Fallback Text'; // Arabic as fallback
            } else if (selectedLanguage == 'en') {
              // If language is English, display English text and fallback to French text
              text = item['en'] ?? '';
              fallback = item['ar'] ?? 'Fallback Text'; // French as fallback
            } else if (selectedLanguage == 'ar') {
              // If language is Arabic, display Arabic text and fallback to French text
              text = item['ar'] ?? '';
              fallback = item['fr'] ?? 'Fallback Text'; // French as fallback
            } else {
              // Default case if no valid language is selected
              text = item['fr'] ?? item['en'] ?? item['ar'] ?? 'Fallback Text';
              fallback = item['fr'] ?? 'Fallback Text'; // Default fallback
            }

            return {
              'text': text, // The main language text
              'fallback': fallback, // The fallback language text
              'index': item['index'], // Ensure index is included
            };
          }).toList();

          sponsorImages = List<String>.from(data['sponsors']);
          // `data['helpDocument']` (the old PDF URL) is intentionally
          // ignored now - help is the in-app FAQ screen, no document to
          // fetch or store.

          isLoading = false; // Stop loading
        });
      } else {
        setState(() {
          isLoading = false; // Stop loading
          hasError = true; // Set error flag
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false; // Stop loading
        hasError = true; // Set error flag
      });
    }
  }

  // ---------------------------------------------------------------------
  // Highlighted-products showcase fetch.
  //
  // This calls the PHP "V1_fp" API - the SAME api_fp/V1_fp host every other
  // fetch on this screen (and search/category/product-detail) already talks
  // to via AppConfig.apiBase. There is no second host to configure: the new
  // `highlighted_products` action lives right next to `sponsors`, `notifs`,
  // etc. in V1_fp.php and reads the `product_highlights` table the web app
  // writes to (same database). It only ever returns entities that have at
  // least one product a platform admin (entité 999/111) has approved, each
  // capped to kShowcaseProductsPerEntity products.
  // ---------------------------------------------------------------------
  Future<void> fetchHighlightedShowcase() async {
    setState(() {
      isShowcaseLoading = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.apiBase}//api_fp/V1_fp/highlighted_products?limit_per_entity=$kShowcaseProductsPerEntity',
      );
      final response = await http.get(uri);
      print('Highlighted showcase: status ${response.statusCode}');

      if (response.statusCode != 200) {
        setState(() {
          showcaseEntities = [];
          isShowcaseLoading = false;
        });
        return;
      }

      final data = json.decode(response.body);
      final entities = List.from(data['entities'] ?? []);
      print('Highlighted showcase: ${entities.length} entity(ies) with approved products');

      setState(() {
        showcaseEntities =
            entities.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        isShowcaseLoading = false;
        _showcasePageIndex = 0;
      });
    } catch (e) {
      // No approved highlights yet, or the endpoint isn't deployed on the
      // PHP API yet (see highlighted_products_get() in V1_fp.php). Either
      // way, fail quiet - the section just stays hidden instead of showing
      // broken content.
      print('Failed to fetch highlighted showcase: $e');
      setState(() {
        showcaseEntities = [];
        isShowcaseLoading = false;
      });
    }
  }

  Future<void> _saveLanguagePreference(String language) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
  }

  // Small helper: pulls the notification menu item (index 2) out of
  // menuItems, with safe fallbacks so the button always has something to
  // show even before/without the sponsors call finishing.
  Map<String, dynamic> _notifMenuItem() {
    final match = menuItems.where((item) => item['index'] == 2);
    if (match.isNotEmpty) return match.first;
    return {
      'text': selectedLanguage == 'fr' ? 'Notifications' : 'Notifications',
      'fallback': 'الإشعارات',
      'index': 2,
    };
  }

  // Compact notification button - the single button kept from the old
  // 3-button row. Flat, on-brand style (pale blue pill, thin border, the
  // app's navy for icon/text), just smaller than before and a small red
  // dot to flag it as "new/flash". No gradients.
  Widget _buildFlashNotificationButton() {
    final notifItem = _notifMenuItem();
    final label = (notifItem['text'] ?? '').toString().trim();

    return Material(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotifPage(
                nameAr: notifItem['text']?.toString() ?? '',
                namefr: notifItem['fallback']?.toString() ?? '',
              ),
            ),
          );
        },
        child: Container(
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none,
                        color: AppColors.primary, size: 22),
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.accentLight, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  label.isNotEmpty ? label : 'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SECTION 1 (product grid): no title of its own anymore - it reads as a
  // continuation of the brand card right above it (same entity, same swipe
  // position visually), just the 2x2 product grid + its own pager/dots.
  // Uses its own pager state (_showcasePageController / _showcasePageIndex)
  // so it can still be swiped independently from the brand showcase above.
  // ---------------------------------------------------------------------
  Widget _buildProductShowcaseSection() {
    if (!isShowcaseLoading && showcaseEntities.isEmpty) {
      // Nothing approved yet - fail gracefully, no empty section.
      return SizedBox.shrink();
    }

    return isShowcaseLoading
        ? _buildProductShowcaseShimmerGrid()
        : _buildProductShowcasePager();
  }

  // The caller bounds this whole section's height (home's body no longer
  // scrolls), so the PageView just fills whatever space it's given via
  // Expanded - it still swipes between entities exactly as before, it's
  // just not sized from a fixed pixel height anymore. Dot indicators sit
  // below it at their own small natural height.
  Widget _buildProductShowcasePager() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _showcasePageController,
            itemCount: showcaseEntities.length,
            onPageChanged: (index) {
              setState(() => _showcasePageIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildProductEntityPage(showcaseEntities[index]);
            },
          ),
        ),
        if (showcaseEntities.length > 1) ...[
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(showcaseEntities.length, (index) {
              final active = index == _showcasePageIndex;
              return AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // One "page" of the product-grid pager: ONE grid where the FIRST tile is
  // that entity's own brand-name/"Voir tous les produits" tile (tap ->
  // EntiteCatalogScreen) and the remaining tiles (up to 3) are its
  // highlighted products (tap -> product detail). No separate entity-name
  // header above the grid anymore - the first tile itself carries that
  // identity now, so the whole box is just the grid.
  Widget _buildProductEntityPage(Map<String, dynamic> entity) {
    final allProducts = List.from(entity['products'] ?? []);
    // 2x2 grid = 4 tiles total: 1 for the entity/"voir tout" tile + up to 3
    // actual highlighted products.
    final products = allProducts.take(3).toList();
    final itemCount = 1 + products.length;

    // LayoutBuilder sees exactly the box this one swipe-page gets (bounded
    // by the pager's Expanded above, in turn bounded by the home screen no
    // longer scrolling) - so the grid's aspect ratio is derived from real
    // available width AND height: the tiles shrink to fit, never clip, and
    // never leave dead space below the last row.
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _gridChildAspectRatio(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: kShowcaseGridSpacing,
            crossAxisSpacing: kShowcaseGridSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildEntiteTileCard(entity);
            }
            return _buildProductShowcaseCard(products[index - 1]);
          },
        );
      },
    );
  }

  // The grid's first tile: this entity's own brand name (the brand of its
  // highlighted products - falls back to the entity/company name when none
  // of them have a brand set) + "Voir tous les produits" - tap opens
  // EntiteCatalogScreen (brand -> category -> product browse for this
  // entity). Text-only now, no logo/initials image. Same card shape as a
  // product tile so it sits naturally in the grid, with a small accent
  // arrow badge to mark it as the "view all" tile.
  Widget _buildEntiteTileCard(Map<String, dynamic> entity) {
    final name = (entity['name'] ?? '').toString();
    final displayName = name.isNotEmpty ? name : '-';
    final logoUrl = (entity['logo'] ?? '').toString();
    final hasLogo = logoUrl.isNotEmpty;
    final idEntite = int.tryParse('${entity['id_entite']}') ?? 0;

    // First non-empty brand among this entity's own highlighted products -
    // that's what the tile shows. No brand on any of them -> the entity's
    // own (company) name instead.
    final entityProducts = List.from(entity['products'] ?? []);
    String brandLabel = '';
    for (final p in entityProducts) {
      if (p is Map) {
        final b = (p['brand'] ?? '').toString().trim();
        if (b.isNotEmpty) {
          brandLabel = b;
          break;
        }
      }
    }
    if (brandLabel.isEmpty) brandLabel = displayName;

    return GestureDetector(
      onTap: () {
        if (idEntite <= 0) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EntiteCatalogScreen(
              idEntite: idEntite,
              entiteName: displayName,
              logoUrl: hasLogo ? logoUrl : null,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.accentLight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text(
                          brandLabel,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
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
                        child: Icon(Icons.arrow_forward,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                selectedLanguage == 'fr'
                    ? 'Voir tous les produits'
                    : 'View all products',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductShowcaseShimmerGrid() {
    // Same box the real pager gets (bounded by the parent Expanded, since
    // home no longer scrolls) - so the shimmer placeholder matches the
    // real grid's size exactly instead of guessing a height from width. No
    // name-bar placeholder anymore either - the real page has no header
    // row above the grid, so neither does this.
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _gridChildAspectRatio(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          itemCount: kShowcaseProductsPerEntity,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: kShowcaseGridSpacing,
            crossAxisSpacing: kShowcaseGridSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: AppColors.surfaceAlt,
              highlightColor: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductShowcaseCard(dynamic product) {
    final images = product['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty)
        ? images[0]?.toString()
        : null;
    final name = (product['productName'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        final gtin = product['gtin']?.toString();
        if (gtin == null || gtin.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(gtin: gtin),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceAlt,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surfaceAlt,
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceAlt,
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                name.isNotEmpty ? name : '-',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The keyboard must NOT resize the home page: the showcase grid sizes
      // itself from the height left on screen, so letting the keyboard
      // shrink the body made the grid cards tiny while typing in the search
      // bar. With this off, the layout keeps its exact size and the
      // keyboard simply slides over the bottom (the search bar is at the
      // top, so it always stays visible).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppConfig.flagAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Image.asset(
                    AppImages.logo,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLanguage,
                    items: [
                      DropdownMenuItem(
                        value: 'fr',
                        child: Text(
                          'Fr',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(
                          'En',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        await _saveLanguagePreference(newValue);
                        setState(() {
                          selectedLanguage = newValue;
                          isDropdownOpen = false; // Close the dropdown
                        });
                        fetchContent(); // Fetch new content based on selected language
                      }
                    },
                    underline: SizedBox(),
                    icon: Icon(
                      isDropdownOpen
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down, // Change icon
                      color: AppColors.primary,
                    ),
                    dropdownColor: Colors.white,
                    onTap: () {
                      setState(() {
                        isDropdownOpen = !isDropdownOpen; // Toggle dropdown state
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      // Flat, modern "help" button - a pale-blue circle with a thin border
      // and a navy outline icon, matching the rest of the app instead of a
      // solid, heavily-shadowed default FAB.
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentLight,
        foregroundColor: AppColors.primary,
        elevation: 1,
        highlightElevation: 2,
        shape: CircleBorder(side: BorderSide(color: AppColors.border)),
        onPressed: _openHelpDocument,
        child: Icon(Icons.help_outline),
      ),
      // Home no longer scrolls to see the banner - everything fits in one
      // screen. Search bar + notification button keep their natural
      // (small, fixed) height; the sponsor carousel below keeps its exact
      // 300px height completely untouched; the showcase grid is the one
      // flexible piece - wrapped in Expanded so IT shrinks to whatever
      // space is left, instead of the page growing taller than the
      // screen. The showcase still swipes between entities exactly as
      // before - only its size changed, not its swipe behavior.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Add search field and icons before showing the data
              CustomSearchBar(selectedLanguage: selectedLanguage),
              SizedBox(height: 10), // Spacer between search bar and content

              Expanded(
                child: isLoading
                    // Shimmer effect while loading
                    ? Column(
                        children: [
                          Shimmer.fromColors(
                            baseColor: AppColors.surfaceAlt,
                            highlightColor: Colors.white,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          SizedBox(height: 14),
                          Expanded(
                            child: Shimmer.fromColors(
                              baseColor: AppColors.surfaceAlt,
                              highlightColor: Colors.white,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : hasError
                        ? Center(
                            child: Text(
                              "There is an error with your connection.",
                              style: TextStyle(
                                  color: AppColors.danger, fontSize: 16),
                            ),
                          )
                        : Column(
                            children: [
                              // Notification button - the single button kept, top of page
                              _buildFlashNotificationButton(),

                              SizedBox(height: 12),

                              // Showcase - one swipeable page per entity, ONE grid per
                              // page: first tile is that entity's logo/"Voir tous les
                              // produits" (tap -> EntiteCatalogScreen), the rest are its
                              // highlighted products (tap -> product detail). No separate
                              // section title (no "Produits en vedette" label). Flexible -
                              // shrinks to fit whatever's left above the fixed-size banner,
                              // still swipeable between entities as before.
                              Expanded(
                                child: _buildProductShowcaseSection(),
                              ),

                              SizedBox(height: 14),

                              // Carousel for sponsor images - flat bordered card, matches
                              // the rest of the app instead of floating on bare background.
                              // Trimmed way down (300 -> 180) so the showcase grid above
                              // gets most of the fixed screen height - the banner stays
                              // visible, just no longer dominates the page.
                              Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    PageView.builder(
                                      controller: _pageController,
                                      itemCount: sponsorImages.length,
                                      itemBuilder: (context, index) {
                                        return Center(
                                          child: CachedNetworkImage(
                                            imageUrl: sponsorImages[index],
                                            fit: BoxFit
                                                .scaleDown, // Ensures the image is not stretched or zoomed
                                            placeholder: (context, url) => CircularProgressIndicator(
                                              color: AppColors.accent,
                                            ),
                                            errorWidget: (context, url, error) => Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline, color: AppColors.textSecondary),
                                                Text(
                                                  "Failed to load image",
                                                  style: TextStyle(color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        icon: Icon(Icons.arrow_back_ios, color: AppColors.primary),
                                        onPressed: () {
                                          _pageController.previousPage(
                                            duration: Duration(milliseconds: 700),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        icon: Icon(Icons.arrow_forward_ios, color: AppColors.primary),
                                        onPressed: () {
                                          _pageController.nextPage(
                                            duration: Duration(milliseconds: 700),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

