import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/assets/app_images.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/splash/pages/SplashPage.dart';
import 'package:flutter/material.dart';

/// Affiché UNE SEULE FOIS, au premier lancement après l'installation :
/// l'utilisateur choisit son pays par défaut. Il pourra le changer ensuite
/// depuis la liste déroulante du drapeau en haut de l'écran.
class CountrySelectionPage extends StatelessWidget {
  const CountrySelectionPage({super.key});

  Future<void> _choose(BuildContext context, Country country) async {
    await AppConfig.setCountry(country);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SplashPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    AppImages.logo,
                    height: 96,
                    width: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Choisissez votre pays',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose your country',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                for (final c in Country.values) ...[
                  _CountryCard(
                    country: c,
                    onTap: () => _choose(context, c),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final Country country;
  final VoidCallback onTap;

  const _CountryCard({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppConfig.flagAssetFor(country),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppConfig.countryName(country),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
