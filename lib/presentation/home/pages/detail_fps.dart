import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/data/models/segment.dart';
import 'package:codeonline_info/presentation/search/pages/ProductDetailsScreen.dart';
import 'package:flutter/material.dart';

class DetailsFps extends StatelessWidget {
  final List<FP> fps;

  DetailsFps({required this.fps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Details'),
      ),
      body: ListView.builder(
        itemCount: fps.length,
        itemBuilder: (context, index) {
          final fp = fps[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    gtin: fp.gtin,
                  ),
                ),
              );
            },
            child: Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0), // Rounded corners
                side: BorderSide(color: AppColors.border), // Flat: border instead of shadow
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        fp.images.first,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit
                            .contain, // Ensure the image fits the container properly
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Brand: ${fp.brand}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Product: ${fp.productName}',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'GTIN: ${fp.gtin}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Country of Origin: ${fp.countryOfOrigin}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Company: ${fp.companyName}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
