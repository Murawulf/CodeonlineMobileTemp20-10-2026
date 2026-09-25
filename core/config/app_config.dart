/// Configuration par pays — sélectionnée au démarrage par main_<pays>.dart.
/// Un seul code source -> N APK pays (Côte d'Ivoire, Tunisie, ...).
enum Country { cotedivoire, tunisie, senegal }

class AppConfig {
  /// Pays actif. Défaut : Côte d'Ivoire. Surchargé dans main_<pays>.dart.
  static Country country = Country.cotedivoire;

  /// Base de l'API PHP (codeonline-fp) du pays.
  static String get apiBase {
    switch (country) {
      case Country.tunisie:
        return 'https://fp.codeonline-info.com';
      case Country.cotedivoire:
        return 'https://civ-fp.codeonline-edi.net';
      case Country.senegal:
        return 'https://sen-fp.codeonline-edi.net';
    }
  }

  /// Drapeau affiché (header + splash).
  static String get flagAsset {
    switch (country) {
      case Country.tunisie:
        return 'assets/images/flag_tn.png';
      case Country.cotedivoire:
        return 'assets/images/flag_ci.png';
      case Country.senegal:
        return 'assets/images/flag_sn.png';
    }
  }

  /// Logo "Côte d'Ivoire Export" : affiché uniquement pour la CIV.
  static bool get showExportLogo => country == Country.cotedivoire;
}