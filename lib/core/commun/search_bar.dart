// custom_search.dart
import 'package:codeonline_info/core/config/assets/app_images.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/home/pages/home.dart';
import 'package:codeonline_info/presentation/home/pages/qrscanner.dart';
import 'package:codeonline_info/presentation/search/pages/search.dart';
import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final String hintText; // Accept hint text as a parameter
  final ValueChanged<String>? onChanged; // optional callback for parent
  final int minSearchLength; // minimum chars required to trigger search
  final String? initialText; // initial text value for the field
  final String selectedLanguage; // language for localization

  const CustomSearchBar({
    super.key,
    this.hintText = 'Brand ou GTIN',
    this.onChanged,
    this.initialText,
    this.minSearchLength = 3,
    this.selectedLanguage = 'en',
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();

  // Localized message based on language
  String _getSearchMinLengthMessage() {
    if (widget.selectedLanguage == 'fr') {
      return 'Veuillez saisir au moins ${widget.minSearchLength} caractères pour rechercher.';
    }
    return 'Please type at least ${widget.minSearchLength} characters to search.';
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText?.trim() ?? '';
  }

  @override
  void didUpdateWidget(CustomSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != null) {
      _controller.text = widget.initialText!.trim();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Retour à la page d'accueil (reset de la pile).
  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText, // Use the hintText parameter
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                // Icône "X" à droite pour effacer (visible si du texte est saisi).
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          _goHome(); // clear and go home only on manual X
                        },
                      ),
                border: InputBorder.none, // Removes the default underline
                contentPadding:
                    EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
              onChanged: (value) {
                setState(() {}); // refresh X icon
                widget.onChanged?.call(value);
              },
              onSubmitted: (query) {
                final q = query.trim();
                if (q.isEmpty) return; // empty -> nothing
                if (q.length < widget.minSearchLength) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_getSearchMinLengthMessage()),
                  ));
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchPage(searchQuery: q),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            final scannedValue = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerScreen(),
              ),
            );

            if (scannedValue != null) {
              // Use the scannedValue as needed
              print("Scanned Value: $scannedValue");
            }
          },
          child: Image.asset(
            AppImages.search,
            height: 50,
          ),
        ),
      ],
    );
  }
}
