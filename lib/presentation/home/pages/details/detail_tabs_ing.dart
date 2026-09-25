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

class DetailTabsIng extends StatefulWidget {
  final String service;
  DetailTabsIng({required this.service});

  @override
  _DetailTabsIngState createState() => _DetailTabsIngState();
}

class _DetailTabsIngState extends State<DetailTabsIng>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _productData;
  late TabController _tabController;
  int _currentImageIndex = 0;
  List<String> _images = [];
  String selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
    _productData = fetchProductData(
        selectedLanguage); // Fetch content when language preference is retrieved
  }

  Future<Map<String, dynamic>> fetchProductData(String selectedLanguage) async {
    final url =
        '${AppConfig.apiBase}//api_fp/V1_fp/fiche_service_by_id?idService=${widget.service}';

    // Set headers conditionally
    final headers = <String, String>{};
    if (selectedLanguage == 'en') {
      headers['x-lang'] = 'en-US';
    }

    // Perform the request with headers
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _nextImage() {
    setState(() {
      if (_currentImageIndex < (_images.length - 1)) {
        _currentImageIndex++;
      }
    });
  }

  void _previousImage() {
    setState(() {
      if (_currentImageIndex > 0) {
        _currentImageIndex--;
      }
    });
  }

  Widget buildLabelValueRow(
      String labelEn, String labelFr, String labelAr, String? value) {
    // Only show the row if the value is not null or empty
    if (value == null || value.isEmpty) {
      return SizedBox.shrink(); // Return an empty widget (nothing is displayed)
    }
    String selectedLabel = selectedLanguage == 'fr' ? labelFr : labelEn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(selectedLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(labelAr,
                  style: TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          SizedBox(height: 4),
          Center(
              child: Text(value,
                  style: TextStyle(fontSize: 16, color: AppColors.primary))),
          SizedBox(height: 30),
        ],
      ),
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

  void _showImagePopup(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          // Set a custom width and height for the dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width:
                MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            height: MediaQuery.of(context).size.height *
                0.6, // 60% of screen height
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit
                        .contain, // Ensure the image fits within the dialog
                    placeholder: (context, url) => Center(
                      child:
                          CircularProgressIndicator(), // Show a loading spinner while the image loads
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.image_not_supported,
                      color: AppColors
                          .textSecondary, // Show an error icon if the image fails to load
                      size: 50,
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

  Widget buildLabelValueRowV1(
      String labelEn, String labelAr, String value, String valueAr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column to stack labels vertically
          Column(
            crossAxisAlignment: CrossAxisAlignment
                .start, // Align both labels to the start (left)
            children: [
              Text(
                labelAr,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                softWrap: true, // Allow text to wrap to the next line if needed
                overflow: TextOverflow
                    .visible, // Ensure text does not overflow with ellipsis
              ),
              SizedBox(height: 4), // Space between labelEn and labelAr
              Text(
                labelEn,
                style: TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                softWrap: true, // Allow text to wrap to the next line if needed
                overflow: TextOverflow
                    .visible, // Ensure text does not overflow with ellipsis
              ),
            ],
          ),
          SizedBox(height: 4), // Space between labels and values
          // Value text section (Centered)
          Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
              ),
              softWrap: true, // Allow text to wrap
              overflow: TextOverflow.visible, // Ensure text does not overflow
            ),
          ),
          SizedBox(height: 4), // Space between value and valueAr
          Center(
            child: Text(
              valueAr,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
              ),
              softWrap: true, // Allow text to wrap
              overflow: TextOverflow.visible, // Ensure text does not overflow
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomSearchBar(selectedLanguage: selectedLanguage),
            ),
            SizedBox(height: 20),
            DefaultTabController(
              length: 2, // 2 tabs: Product and Producer
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        text:
                            selectedLanguage == 'fr' ? 'Services' : 'Services',
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
                  // Avoid using Expanded directly in unbounded containers
                  Container(
                    height: MediaQuery.of(context).size.height -
                        200, // or any fixed height
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
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data == null) {
                          return Center(child: Text('No data available.'));
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
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product images and navigation
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Only show the previous button if there are more than 1 image
                                          if (_images.length > 1)
                                            IconButton(
                                              icon: Icon(Icons.arrow_back),
                                              onPressed: _previousImage,
                                            ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                // Show the image in full-screen when clicked
                                                _showImagePopup(
                                                    context,
                                                    data['images']
                                                        [_currentImageIndex]);
                                              },
                                              child: Center(
                                                child: data['images'] != null &&
                                                        data['images']
                                                            .isNotEmpty
                                                    ? Image.network(
                                                        data['images'][
                                                            _currentImageIndex],
                                                        height: 200,
                                                      )
                                                    : Text(
                                                        "No image available"),
                                              ),
                                            ),
                                          ),
                                          // Only show the next button if there are more than 1 image
                                          if (_images.length > 1)
                                            IconButton(
                                              icon: Icon(Icons.arrow_forward),
                                              onPressed: _nextImage,
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      buildLabelValueRowV1(
                                        data['titreService_ar'],
                                        data['titreService'],
                                        data['texteService'],
                                        data['texteService_ar'],
                                      ),
                                      buildLabelValueRow('Country', 'Pays',
                                          'البلد', data['countryOfOrigin']),
                                      buildLabelValueRow(
                                          'Company Name',
                                          'Nom de l’entreprise',
                                          'اسم الشركة',
                                          data['companyName']),
                                    ],
                                  ),
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
          ],
        ),
      ),
    );
  }
}
