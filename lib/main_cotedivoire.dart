import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'main.dart';

/// Point d'entrée APK Côte d'Ivoire.
/// Build : flutter build apk --release --flavor cotedivoire -t lib/main_cotedivoire.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.country = Country.cotedivoire;
  runApp(const MyApp());
}
