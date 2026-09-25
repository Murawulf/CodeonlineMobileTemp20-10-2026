import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'main.dart';

/// Point d'entrée APK Tunisie.
/// Build : flutter build apk --release --flavor tunisie -t lib/main_tunisie.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.country = Country.tunisie;
  runApp(const MyApp());
}
