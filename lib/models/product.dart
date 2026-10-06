class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final int stock;
  final List<String> images; // Images uploaded by the vendor
  final List<String> colors;
  final List<String> sizes;
  final Vendor vendor;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.stock,
    required this.images,
    required this.colors,
    required this.sizes,
    required this.vendor,
  });

  /// Builds a product from the flattened payload the API layer produces for
  /// cart lines. Tolerates missing keys so a partially hydrated line still
  /// renders instead of throwing.
  factory Product.fromJson(Map<String, dynamic> json) {
    final rawOldPrice = json['oldPrice'];
    final images = json['images'];
    final vendor = json['vendor'];
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _toDouble(json['price']),
      oldPrice: rawOldPrice == null ? null : _toDouble(rawOldPrice),
      stock: _toInt(json['stock']),
      images: images is List
          ? images.map((e) => e.toString()).toList()
          : const <String>[],
      colors: json['colors'] is List
          ? (json['colors'] as List<dynamic>).map((e) => e.toString()).toList()
          : const <String>[],
      sizes: json['sizes'] is List
          ? (json['sizes'] as List<dynamic>).map((e) => e.toString()).toList()
          : const <String>[],
      vendor: vendor is Map
          ? Vendor.fromJson(Map<String, dynamic>.from(vendor))
          : Vendor.empty(),
    );
  }
}

double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : (double.tryParse('$value') ?? 0);

int _toInt(dynamic value) =>
    value is int ? value : (value is num ? value.toInt() : (int.tryParse('$value') ?? 0));

class Vendor {
  final String id;
  final String name;
  final String logo;
  final double rating;
  final int totalProducts;

  Vendor({
    required this.id,
    required this.name,
    required this.logo,
    required this.rating,
    required this.totalProducts,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'MVEC seller',
    logo: json['logo']?.toString() ?? '',
    rating: _toDouble(json['rating']),
    totalProducts: _toInt(json['totalProducts']),
  );

  /// Placeholder used when a product arrives without its vendor snapshot, so a
  /// missing relation never breaks a list render.
  factory Vendor.empty() => Vendor(
    id: '',
    name: 'MVEC seller',
    logo: '',
    rating: 0,
    totalProducts: 0,
  );
}