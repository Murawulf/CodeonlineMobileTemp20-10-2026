import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/config/theme/app_theme.dart';
import 'presentation/country/pages/country_selection_page.dart';
import 'presentation/splash/pages/SplashPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Recharge le pays choisi par l'utilisateur (s'il y en a un).
  await AppConfig.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Pinned to light + a single explicit theme: previously no theme was
      // set at all, so the whole app silently fell back to Flutter's
      // default (purple-seeded) Material theme wherever a widget didn't
      // hardcode its own color. AppTheme.lightTheme is the real, flat,
      // blue design system - see app_theme.dart. themeMode is pinned to
      // light so a device in system dark mode can't switch anything
      // (nothing in this app has a dark-mode design), and scaffold
      // backgrounds stay white, matching what SplashPage already renders
      // today - untouched on purpose.
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      // Premier lancement après installation -> choix du pays ; ensuite
      // directement le splash avec le pays mémorisé.
      home: AppConfig.hasSavedCountry
          ? SplashPage()
          : const CountrySelectionPage(),
    );
  }
}
