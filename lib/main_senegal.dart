import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'main.dart';

/// Point d'entrée APK Sénégal.
/// Build : flutter build apk --release --flavor senegal -t lib/main_senegal.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.country = Country.senegal;
  runApp(const MyApp());
}
