import 'package:cached_network_image/cached_network_image.dart';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/search/pages/ProductDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart'; // Import the shimmer package

class CategoryDetailsScreen extends StatefulWidget {
  final String brand;
  final String categoryCode;
  final String categoryName;
  final String? searchQuery;

  CategoryDetailsScreen(
      {required this.brand,
      required this.categoryCode,
      required this.categoryName,
      this.searchQuery});

  @override
  _CategoryDetailsScreenState createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  late Future<List<dynamic>> _productData;
  String selectedLanguage = 'en';
  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
    _productData = fetchProductData();
  }

  // Fetch product data using brand and categoryCode
  Future<List<dynamic>> fetchProductData() async {
    Uri uri = Uri.parse(
        '${AppConfig.apiBase}//api_fp/V1_fp/fiche_produit_by_brand_category?brand=${widget.brand}&categoryCode=${widget.categoryCode}&page=1');
    final headers = <String, String>{};
    if (selectedLanguage == 'en') {
      headers['x-lang'] = 'en-US';
    }

    // Make the GET request with the headers
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body); // Decode the response body
      List<dynamic> productList =
          data['items']; // Extract the 'items' list from the response
      return productList; // Return the list of products
    } else {
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          // CustomSearchBar will appear first
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomSearchBar(
              hintText: widget.brand,
              initialText: widget.searchQuery,
              selectedLanguage: selectedLanguage,
            ),
          ),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(
                widget.categoryName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          SizedBox(height: 10),
          // FutureBuilder for loading products
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _productData,
              builder: (context, snapshot) {
                // While loading, show the shimmer effect
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    itemCount: 5, // Display 5 shimmer items for loading
                    itemBuilder: (context, index) {
                      return Shimmer.fromColors(
                        baseColor: AppColors.surfaceAlt,
                        highlightColor: Colors.white,
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  color: AppColors
                                      .surfaceAlt, // Shimmer container for image
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 20,
                                        color: AppColors
                                            .surfaceAlt, // Shimmer container for text
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        height: 20,
                                        color: AppColors
                                            .surfaceAlt, // Shimmer container for text
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        height: 20,
                                        color: AppColors
                                            .surfaceAlt, // Shimmer container for text
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                } else {
                  var products = snapshot.data!;
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      var product = products[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                gtin: product['gtin'],
                                initialSearchQuery: widget.searchQuery,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: product['images'][
                                      0], // Assuming images is an array, and we use the first image
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.accent,
                                    ), // Show a loading spinner while the image loads
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported,
                                    color: AppColors
                                        .textSecondary, // Show an error icon if the image fails to load
                                    size: 40,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['productName'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'GTIN: ${product['gtin'] ?? 'N/A'}',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        selectedLanguage == 'fr'
                                            ? "Pays : ${product['countryOfOrigin']}" // French text
                                            : "Country: ${product['countryOfOrigin']}", // English text
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                        softWrap:
                                            true, // Allows the text to wrap
                                        overflow: TextOverflow
                                            .ellipsis, // Adds ellipsis if the text is too long
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
