class Segment {
  final String nameFr;
  final String nameAr;
  final String code;
  final List<Category> categories;

  Segment(
      {required this.nameFr,
      required this.nameAr,
      required this.code,
      required this.categories});

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      nameFr: json['segment']['libelleSegment'] ??
          '', // Correct the field name to match the JSON structure
      nameAr: json['segment']['libelleSegment_ar'] ?? '',
      code: json['segment']['codeSegment'] ?? '',
      categories: (json['categories'] as List)
          .map((item) => Category.fromJson(item))
          .toList(),
    );
  }
}

class Category {
  final String nameFr;
  final String nameAr;
  final String libelleBrique;
  final String libelleBrique_ar;
  final String code;
  final List<FP> fps;

  Category(
      {required this.nameFr,
      required this.nameAr,
      required this.libelleBrique,
      required this.libelleBrique_ar,
      required this.code,
      required this.fps});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      nameFr: json['name_fr'] ?? '',
      nameAr: json['name_ar'] ?? '',
      libelleBrique: json['libelleBrique'] ??
          '', // Ensure this key matches your data structure
      libelleBrique_ar: json['libelleBrique_ar'] ?? '', // Same for this one
      code: json['code'] ?? '',
      fps: (json['FPs'] as List).map((item) => FP.fromJson(item)).toList(),
    );
  }
}

class FP {
  final List<String> images;
  final String brand;
  final String productName;
  final String gtin;
  final String countryOfOrigin;
  final String prixMin;
  final String prixMax;
  final String companyName;

  FP({
    required this.images,
    required this.brand,
    required this.productName,
    required this.gtin,
    required this.countryOfOrigin,
    required this.prixMin,
    required this.prixMax,
    required this.companyName,
  });

  factory FP.fromJson(Map<String, dynamic> json) {
    return FP(
      images: List<String>.from(json['images']),
      brand: json['brand'] ?? '',
      productName: json['productName'] ?? '',
      gtin: json['gtin'] ?? '',
      countryOfOrigin: json['countryOfOrigin'] ?? '',
      prixMin: json['prixMin'] ?? '',
      prixMax: json['prixMax'] ?? '',
      companyName: json['companyName'] ?? '',
    );
  }
}
