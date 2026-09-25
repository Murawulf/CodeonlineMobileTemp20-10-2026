import 'package:codeonline_info/core/config/assets/app_images.dart';
import "package:codeonline_info/core/config/app_config.dart";
import 'package:codeonline_info/presentation/home/pages/home.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    // Navigate to the home screen after a 5-second delay
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                HomeScreen()), // Replace with your HomePage widget
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Logo — drapeau forcé en cercle, taille + position UNIFORMES
            // pour tous les pays (SizedBox contraint la boîte quel que soit le
            // ratio de l'image source : carré, 3:2, 16:9…).
            Padding(
              padding: const EdgeInsets.only(top: 70.0),
              child: ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    AppConfig.flagAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Center Logo — forcé en cercle, ~100px (premier écran)
            ClipOval(
              child: Image.asset(
                AppImages.logo,
                height: 105,
                width: 105,
                fit: BoxFit.cover,
              ),
            ),

            // Footer — logo "Côte d'Ivoire Export" uniquement pour la CIV
            Column(
              children: [
                if (AppConfig.showExportLogo) ...[
                  Image.asset(AppImages.footerLogo),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'V 3.0 Copyrights 2014 - 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54, // Adjust color as needed
                  ),
                ),
                const SizedBox(height: 16), // Spacing from the bottom
              ],
            ),
          ],
        ),
      ),
    );
  }
}
