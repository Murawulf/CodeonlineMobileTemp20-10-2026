import 'package:codeonline_info/core/config/app_config.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Drapeau du pays actif + petite flèche : au clic, une liste déroulante
/// avec les noms des pays. Le choix est mémorisé et toute l'app bascule
/// immédiatement sur le pays choisi (API, drapeau, logo...).
class CountrySelector extends StatelessWidget {
  final double flagSize;

  const CountrySelector({super.key, this.flagSize = 42});

  Widget _flag(Country c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipOval(
        child: Image.asset(
          AppConfig.flagAssetFor(c),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Country>(
      valueListenable: AppConfig.countryNotifier,
      builder: (context, current, _) {
        return PopupMenuButton<Country>(
          tooltip: AppConfig.countryName(current),
          initialValue: current,
          position: PopupMenuPosition.under,
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (Country selected) {
            if (selected == AppConfig.country) return;
            // Met à jour l'UI en temps réel (l'accueil recharge ses données
            // via le notifier) et mémorise le choix.
            AppConfig.setCountry(selected);
            // Les écrans ouverts (produit, recherche...) appartenaient à
            // l'ancien pays : retour à l'accueil, déjà rechargé.
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          itemBuilder: (context) => Country.values.map((c) {
            final isSelected = c == current;
            return PopupMenuItem<Country>(
              value: c,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _flag(c, 28),
                  const SizedBox(width: 12),
                  Text(
                    AppConfig.countryName(c),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.check, size: 18, color: AppColors.accent),
                  ],
                ],
              ),
            );
          }).toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _flag(current, flagSize),
              const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            ],
          ),
        );
      },
    );
  }
}
