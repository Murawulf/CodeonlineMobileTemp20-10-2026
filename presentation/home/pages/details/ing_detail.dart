import 'package:cached_network_image/cached_network_image.dart';
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/data/models/segment.dart';
import 'package:codeonline_info/presentation/home/pages/details/detail_tabs_ing.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IngDetail extends StatefulWidget {
  final Segment segment;
  final String name;

  IngDetail({required this.segment, required this.name});

  @override
  _IngDetailState createState() => _IngDetailState();
}

class _IngDetailState extends State<IngDetail> {
  // Track the index of the currently expanded card
  int? expandedIndex;
  String selectedLanguage = 'en';
  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage =
          prefs.getString('language') ?? 'en'; // Default to 'en' if not set
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            CustomSearchBar(selectedLanguage: selectedLanguage),
            SizedBox(height: 20),

            // Engineering & Services section
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    widget.segment.nameFr.isEmpty
                        ? widget.segment.nameAr
                        : widget.segment.nameFr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    widget.segment.nameAr.isEmpty
                        ? widget.segment.nameFr
                        : widget.segment.nameAr,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),

            // List of Categories
            Expanded(
              child: ListView.builder(
                itemCount: widget.segment.categories.length,
                itemBuilder: (context, index) {
                  final category = widget.segment.categories[index];
                  String title = category.libelleBrique.isEmpty
                      ? category.nameFr
                      : category.libelleBrique;
                  String titleAr = category.libelleBrique_ar.isEmpty
                      ? category.nameAr
                      : category.libelleBrique_ar;
                  List<FP> fps = category.fps;

                  return Column(
                    children: [
                      // Add space between cards
                      SizedBox(height: 15),

                      // Category Card with GestureDetector for expanding
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            // Toggle expansion for the tapped card
                            expandedIndex =
                                (expandedIndex == index) ? null : index;
                          });
                        },
                        child: _buildCategoryCard(title, titleAr),
                      ),

                      // Expanded view for additional details (if expanded)
                      // Inside _buildExpandedDetails where you handle the onTap for navigating
                      if (expandedIndex == index)
                        GestureDetector(
                          onTap: () {
                            // Set service based on the index (e.g., index + 1)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailTabsIng(
                                    service: (index + 1)
                                        .toString()), // Automatically pass index as service
                              ),
                            );
                          },
                          child: _buildExpandedDetails(fps),
                        ),
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

  // Category Card to display the title and titleAr
  Widget _buildCategoryCard(String title, String titleAr) {
    return Container(
      width: double.infinity,
      height: 70, // Set a fixed height for uniformity
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            titleAr,
            style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18),
          ),
        ],
      ),
    );
  }

  // Expanded Details View for displaying additional FP items
  Widget _buildExpandedDetails(List<FP> items) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.map((fp) {
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Fixed width for the image to avoid overflow
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(8), // Rounded corners for the image
                  child: CachedNetworkImage(
                    imageUrl: fp.images.isNotEmpty ? fp.images[0] : '',
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ), // Show a circular progress indicator
                    ), // Show a placeholder while loading
                    errorWidget: (context, url, error) => Icon(
                      Icons.image_not_supported,
                      color: AppColors
                          .textSecondary, // Show an error icon if the image fails to load
                      size: 50,
                    ), // Show an error image on failure
                  ),
                ),
                SizedBox(width: 15),
                // Wrap the Column inside an Expanded widget
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Name with text wrapping and ellipsis for overflow
                      Text(
                        selectedLanguage == 'fr'
                            ? "Entreprise : ${fp.companyName}" // French text
                            : "Company: ${fp.companyName}", // English text
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true, // Allows the text to wrap
                        overflow: TextOverflow
                            .ellipsis, // Adds ellipsis if the text is too long
                      ),

                      SizedBox(height: 6),
                      // Country Name with text wrapping and ellipsis for overflow
                      Text(
                        selectedLanguage == 'fr'
                            ? "Pays : ${fp.countryOfOrigin}" // French text
                            : "Country: ${fp.countryOfOrigin}", // English text
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        softWrap: true, // Allows the text to wrap
                        overflow: TextOverflow
                            .ellipsis, // Adds ellipsis if the text is too long
                      ),
                    ],
                  ),
                ),
                // Fixed width for the icon to avoid overflow
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textSecondary,
                  size: 20, // Set a fixed size for the icon
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
