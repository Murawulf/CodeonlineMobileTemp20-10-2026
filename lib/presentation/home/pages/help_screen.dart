import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replaces the old "open a PDF" help button. This is a self-contained,
/// bilingual (English/French - matching the app's own Fr/En language
/// toggle, no Arabic here since the app itself doesn't offer that option)
/// FAQ screen: every question and answer below is baked into the app at
/// build time. There is no network call anywhere in this file and nothing
/// the user does here (opening a question, closing it, scrolling) is sent
/// anywhere - it only ever reads the same local, on-device language
/// preference every other screen already reads, purely to decide which of
/// the two pre-written texts to show.
class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  _HelpScreenState createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String selectedLanguage = 'en';
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _getLanguagePreference();
  }

  Future<void> _getLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  bool get _fr => selectedLanguage == 'fr';

  // ---------------------------------------------------------------------
  // The FAQ content itself - every entry is {questionEn, answerEn,
  // questionFr, answerFr}. Covers what's actually in this app: search by
  // brand/GTIN, the barcode scanner, brand search results, the entity
  // "Voir tous les produits" tile, the Product/Producer tabs, the
  // tap-to-zoom product image, flash notifications, regulated/tariffed
  // pricing, the language switch, and this screen's own privacy note.
  // ---------------------------------------------------------------------
  static const List<Map<String, String>> _faq = [
    {
      'qEn': 'How do I search for a product?',
      'aEn':
          'Type a brand name or a GTIN in the search bar at the top of the home screen. The GTIN is the number printed under the barcode on the product\'s label - GTIN stands for Global Trade Item Number, the universal identifier of a fast-moving consumer good.',
      'qFr': 'Comment rechercher un produit ?',
      'aFr':
          'Tapez un nom de marque ou un GTIN dans la barre de recherche en haut de l\'écran d\'accueil. Le GTIN (Global Trade Item Number) est le numéro imprimé sous le code-barres sur l\'étiquette du produit : c\'est l\'identifiant universel d\'un produit de grande consommation (PGC).',
    },
    {
      'qEn': 'Can I scan a barcode instead of typing?',
      'aEn':
          'Yes - tap the barcode icon next to the search bar to scan a product\'s barcode directly with your camera.',
      'qFr': 'Puis-je scanner un code-barres au lieu de taper ?',
      'aFr':
          'Oui - appuyez sur l\'icône du code-barres à côté de la barre de recherche pour scanner directement le code-barres d\'un produit avec votre appareil photo.',
    },
    {
      'qEn': 'What happens when I search by brand?',
      'aEn':
          'The app shows every brand matching what you typed, each with its own list of product categories. Tap a category to see its products.',
      'qFr': 'Que se passe-t-il quand je recherche par marque ?',
      'aFr':
          'L\'application affiche toutes les marques correspondant à votre saisie, chacune avec sa propre liste de catégories de produits. Appuyez sur une catégorie pour voir ses produits.',
    },
    {
      'qEn': 'What\'s the "Voir tous les produits" tile on the home screen?',
      'aEn':
          'It\'s the first tile in each company\'s showcase on the home screen. Tap it to browse everything that company sells, organized by brand and category.',
      'qFr': 'Que fait la case "Voir tous les produits" sur l\'accueil ?',
      'aFr':
          'C\'est la première case dans la vitrine de chaque entreprise sur l\'écran d\'accueil. Appuyez dessus pour parcourir tout ce que cette entreprise vend, organisé par marque et catégorie.',
    },
    {
      'qEn': 'What\'s shown on a product\'s "Product" tab?',
      'aEn':
          'Its brand, GTIN, product name, country of origin and sales typology, whenever that information is available.',
      'qFr': 'Que contient l\'onglet "Produit" d\'une fiche produit ?',
      'aFr':
          'Sa marque, son GTIN, son nom de produit, son pays d\'origine et sa typologie de vente, lorsque ces informations sont disponibles.',
    },
    {
      'qEn': 'What\'s shown on the "Producer" tab?',
      'aEn':
          'The manufacturer\'s company name, GLN, address, phone number, email and website, whenever they\'ve been provided.',
      'qFr': 'Que contient l\'onglet "Producteur" ?',
      'aFr':
          'Le nom de l\'entreprise fabricante, son GLN, son adresse, son numéro de téléphone, son e-mail et son site web, lorsqu\'ils sont fournis.',
    },
    {
      'qEn': 'Can I see a bigger version of a product\'s photo?',
      'aEn':
          'Yes - tap the product image (the small badge in its corner marks it as tappable) to open it full-size, with pinch-to-zoom.',
      'qFr': 'Puis-je voir une version plus grande de la photo d\'un produit ?',
      'aFr':
          'Oui - appuyez sur l\'image du produit (le petit badge dans son coin indique qu\'elle est cliquable) pour l\'ouvrir en taille réelle, avec zoom tactile.',
    },
    {
      'qEn': 'What are the flash notifications?',
      'aEn':
          'Official announcements from the Export Promotion Centre. Tap the notification bar on the home screen to read them.',
      'qFr': 'Que sont les notifications flash ?',
      'aFr':
          'Les annonces officielles du Centre de Promotion des Exportations. Appuyez sur la barre de notifications sur l\'écran d\'accueil pour les lire.',
    },
    {
      'qEn': 'Why do some products show a regulated price?',
      'aEn':
          'For essential/tariffed products, prices - and manufacturer/distributor margins - are set by the Ministry of Commerce and Export Development rather than by the seller.',
      'qFr': 'Pourquoi certains produits affichent-ils un prix réglementé ?',
      'aFr':
          'Pour les produits essentiels/tarifés, les prix - et les marges du fabricant/distributeur - sont fixés par le ministère du Commerce et du Développement des exportations, et non par le vendeur.',
    },
    {
      'qEn': 'How do I switch between French and English?',
      'aEn':
          'Tap the "Fr"/"En" selector in the top-right corner of the home screen and choose your language.',
      'qFr': 'Comment passer du français à l\'anglais ?',
      'aFr':
          'Appuyez sur le sélecteur "Fr"/"En" en haut à droite de l\'écran d\'accueil et choisissez votre langue.',
    },
    {
      'qEn': 'Does this help screen send any of my data anywhere?',
      'aEn':
          'No. Every answer on this screen is built into the app itself - nothing you do here (opening a question, scrolling) is sent anywhere.',
      'qFr': 'Cet écran d\'aide envoie-t-il mes données quelque part ?',
      'aFr':
          'Non. Chaque réponse sur cet écran est intégrée à l\'application elle-même - rien de ce que vous faites ici (ouvrir une question, faire défiler) n\'est envoyé où que ce soit.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_outline, color: AppColors.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fr
                        ? 'Questions fréquentes'
                        : 'Frequently asked questions',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              _fr
                  ? 'Appuyez sur une question pour voir la réponse.'
                  : 'Tap a question to see its answer.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 16),
            for (int i = 0; i < _faq.length; i++) _buildFaqCard(i),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCard(int index) {
    final item = _faq[index];
    final isOpen = _expanded.contains(index);
    final question = _fr ? item['qFr']! : item['qEn']!;
    final answer = _fr ? item['aFr']! : item['aEn']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isOpen) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down,
                          color: AppColors.accent),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: Duration(milliseconds: 200),
                  crossFadeState: isOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: SizedBox(width: double.infinity, height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
