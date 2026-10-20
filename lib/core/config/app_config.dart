import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pays disponibles. Un seul APK/IPA pour tous : le pays est choisi par
/// l'utilisateur au premier lancement, puis modifiable à tout moment via la
/// liste déroulante du drapeau (en haut de l'écran).
enum Country { cotedivoire, tunisie, senegal }

class AppConfig {
  static const String _prefsKey = 'country';

  /// Pays actif. C'est un ValueNotifier : tout widget qui l'écoute
  /// (drapeau, écran d'accueil...) se met à jour en temps réel quand
  /// l'utilisateur change de pays.
  static final ValueNotifier<Country> countryNotifier =
      ValueNotifier<Country>(Country.cotedivoire);

  /// `false` tant que l'utilisateur n'a jamais choisi de pays
  /// (= premier lancement après installation).
  static bool hasSavedCountry = false;

  /// Pays actif (lecture seule pour le reste de l'app : inchangé).
  static Country get country => countryNotifier.value;

  /// Change le pays SANS le sauvegarder. Préférer [setCountry].
  static set country(Country value) => countryNotifier.value = value;

  /// À appeler une fois dans main() avant runApp().
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        for (final c in Country.values) {
          if (c.name == saved) {
            countryNotifier.value = c;
            hasSavedCountry = true;
            break;
          }
        }
      }
    } catch (_) {
      // Lecture impossible -> on retombe sur l'écran de choix du pays.
    }
  }

  /// Change le pays (mise à jour instantanée de l'UI) et le mémorise.
  static Future<void> setCountry(Country value) async {
    countryNotifier.value = value;
    hasSavedCountry = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (_) {}
  }

  /// Base de l'API PHP (codeonline-fp) du pays.
  static String apiBaseFor(Country c) {
    switch (c) {
      case Country.tunisie:
        return 'https://fp.codeonline-info.com';
      case Country.cotedivoire:
        return 'https://civ-fp.codeonline-edi.net';
      case Country.senegal:
        return 'https://sen-fp.codeonline-edi.net';
    }
  }

  static String get apiBase => apiBaseFor(country);

  /// Drapeau d'un pays donné.
  static String flagAssetFor(Country c) {
    switch (c) {
      case Country.tunisie:
        return 'assets/images/flag_tn.png';
      case Country.cotedivoire:
        return 'assets/images/flag_ci.png';
      case Country.senegal:
        return 'assets/images/flag_sn.png';
    }
  }

  /// Drapeau affiché (header + splash).
  static String get flagAsset => flagAssetFor(country);

  /// Nom affiché dans la liste des pays.
  static String countryName(Country c) {
    switch (c) {
      case Country.tunisie:
        return 'Tunisie';
      case Country.cotedivoire:
        return "Côte d'Ivoire";
      case Country.senegal:
        return 'Sénégal';
    }
  }

  /// Logo "Côte d'Ivoire Export" : affiché uniquement pour la CIV.
  static bool get showExportLogo => country == Country.cotedivoire;
}
