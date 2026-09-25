import 'package:codeonline_info/core/config/assets/app_images.dart';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/home/pages/home.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () {
          // Use Future.microtask to schedule the navigation action safely
          Future.microtask(() {
            // Try popping the current route
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Go back when the back icon is clicked
            } else {
              // If pop doesn't work, navigate to HomeScreen forcefully
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            }
          });
        },
      ),
      title: Center(
        child: SizedBox(
          height: 47,
          width: 47,
          child: Image.asset(
            AppImages.logo,
            fit: BoxFit.cover,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
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
      ],
    );
  }
}
