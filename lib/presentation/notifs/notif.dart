import 'dart:convert';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/commun/search_bar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:html/parser.dart' as html;

class NotifPage extends StatefulWidget {
  const NotifPage({super.key, required this.namefr, required this.nameAr});
  final String namefr;
  final String nameAr;
  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  String selectedLanguage = '';
  bool isLoading = true;
  List<dynamic> notifications = [];

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
      _fetchNotifications(selectedLanguage);
    });
  }

  Future<void> _fetchNotifications(String selectedLanguage) async {
    // Initialize the headers map
    Map<String, String> headers = {};

    // Check the selected language and add the appropriate x-lang header
    if (selectedLanguage == "en") {
      headers['x-lang'] = 'en-US';
    } else if (selectedLanguage == "fr") {
      headers['x-lang'] = 'fr-FR';
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBase}//api_fp/V1_fp/notifs'),
      headers: headers, // Pass headers here
    );

    if (response.statusCode == 200) {
      setState(() {
        notifications = json.decode(response.body);
        isLoading = false; // Set loading to false when data is fetched
      });
    } else {
      // Handle error if needed
      print('Failed to load notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: isLoading
          ? _buildShimmer() // Show shimmer effect while loading
          : _buildNotifications(), // Show the notifications when data is ready
    );
  }

  // Shimmer effect widget
  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 5, // Show 5 shimmer loading placeholders
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Shimmer.fromColors(
            baseColor: AppColors.surfaceAlt,
            highlightColor: Colors.white,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 20,
                    color: AppColors.surfaceAlt,
                  ),
                  SizedBox(height: 10),
                  Container(
                    width: 150,
                    height: 20,
                    color: AppColors.surfaceAlt,
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 100,
                    color: AppColors.surfaceAlt,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Display fetched notifications
  Widget _buildNotifications() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  widget.nameAr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  widget.namefr,
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

          // Notifications list
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              shrinkWrap: true,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final formattedDate =
                    DateFormat('dd-MM-yyyy').format(DateTime.now());

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      // Blue container with date and titles
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                formattedDate, // Display current date
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            SizedBox(height: 30),
                            Text(
                              notif['titreNotif'] ?? '', // English Title
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 30),
                            Text(
                              notif['titreNotifAr'] ?? '', // Arabic Title
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),

                      // White container with description text
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _removeHtmlTags(notif['textNotif'] ??
                                  ''), // English Description
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _removeHtmlTags(notif['textNotifAr'] ??
                                  ''), // Arabic Description
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: AppColors.textSecondary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Function to remove <br> tags from the HTML text
  String _removeHtmlTags(String text) {
    var document = html.parse(text);
    return document.body?.text ?? text; // Return cleaned text
  }
}
