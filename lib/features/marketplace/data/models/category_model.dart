/// Category model mirroring the backend category schema
/// (`id`, `name`, `slug`, `productCount`, `media.mainImage`).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.productCount = 0,
  });

  /// Backend identifier; see the note on `Product.id`.
  final String id;
  final String name;
  final String slug;
  final String imageUrl;
  final int productCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    return Category(
      id: _toId(json['id']),
      name: _toString(json['name']),
      slug: _toString(json['slug']),
      imageUrl: media is Map
          ? _toString(media['mainImage'])
          : _toString(json['icon'] ?? json['image_url'] ?? json['image']),
      productCount: _toInt(json['productCount'] ?? json['product_count']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'slug': slug,
        'productCount': productCount,
        'media': <String, dynamic>{
          'mainImage': imageUrl,
        },
      };

  static String _toString(dynamic value) => value?.toString() ?? '';

  static int _toInt(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;

  static String _toId(dynamic value) => value?.toString() ?? '';
}