import '../../../../core/api_client.dart';
import 'home_service.dart';

/// Live implementation of [HomeService] backed by the MVEC API.
///
/// The web frontend builds its storefront the same way: `loadCatalog()` in
/// `src/services/catalogApi.js` fans out to `productsApi.getAll()`,
/// `categoriesApi.getAll()` and `vendorsApi.getAll()` and maps each record into
/// its UI shape. This service mirrors that fan-out so the mobile home feed
/// shows the same catalogue the web storefront does.
///
/// The backend returns a different key vocabulary than the mobile models read
/// (`mainImage` / `gallery[0]` rather than `media.mainImage`, `discountPrice`
/// rather than `originalPrice`, `vendor.companyName` rather than `vendor.name`),
/// so every record is normalised here. That keeps [Product.fromJson] and friends
/// untouched and confines the backend dialect to one file.
///
/// Sections degrade independently, matching the web behaviour where a failed
/// `Promise.allSettled` leg contributes an empty list instead of blanking the
/// page. Only a total failure - every leg failing - is reported as an error.
class ApiHomeService implements HomeService {
  ApiHomeService([ApiClient? api]) : _api = api ?? ApiClient.instance;

  /// How many products the storefront shows in the grid and the recommendation
  /// rail. Kept modest so the first paint stays fast.
  static const _productLimit = 24;

  /// How many storefront banners to request. The backend has no banner resource,
  /// so this is derived from the most recent products (see [getHomeFeed]).
  static const _bannerCount = 3;

  /// How many vendors to feature in the store rail.
  static const _vendorLimit = 8;

  final ApiClient _api;

  @override
  bool get isDemo => false;

  @override
  Future<Map<String, dynamic>> getHomeFeed() async {
    // Same fan-out as the web catalogue loader: one failing leg must not blank
    // the whole home feed.
    final results = await Future.wait(<Future<Object?>>[
      _try(() => _api.get('/products', query: <String, dynamic>{
            'limit': _productLimit,
          })),
      _try(() => _api.get('/categories')),
      _try(() => _api.get('/vendors', query: <String, dynamic>{
            'limit': _vendorLimit,
          })),
    ]);

    if (results.every((result) => result is ApiException)) {
      // Nothing at all came back: surface the first real reason so the UI can
      // tell the shopper the catalogue is unreachable instead of showing an
      // empty store with no explanation.
      throw results.first!;
    }

    final products =
        results[0]
            .let((json) => listJson(json, const ['products']))
            .map(_normaliseProduct)
            .whereType<Map<String, dynamic>>()
            .toList();
    final categories =
        results[1]
            .let((json) => listJson(json, const ['categories']))
            .map(_normaliseCategory)
            .toList();
    final vendors =
        results[2]
            .let((json) => listJson(json, const ['vendors']))
            .map(_normaliseVendor)
            .toList();

    // The backend exposes no banner resource, and the web frontend has no
    // banner content either. Rather than invent promotional rows, the carousel
    // is built from the newest real products; with no products it is simply
    // absent, which is the honest state.
    final banners =
        products
            .where((product) => (product['media'] as Map?)?['mainImage'] != null)
            .take(_bannerCount)
            .map(
              (product) => <String, dynamic>{
                'id': product['id'],
                'title': product['name'],
                'subtitle': _bannerSubtitle(product),
                'media': product['media'],
              },
            )
            .toList();

    final featured =
        products.where((product) => product['isFeatured'] == true).toList();
    // Fall back to the full list so the "Featured" rail still renders when the
    // backend does not flag anything as featured.
    final featuredProducts = featured.isEmpty ? products : featured;

    return <String, dynamic>{
      'banners': banners,
      'categories': categories,
      'featuredVendors': vendors,
      'featuredProducts': featuredProducts,
      'recommendedProducts': products,
      'products': products,
    };
  }

  /// Runs [call], converting a transport failure into an [ApiException] value so
  /// one dead endpoint cannot take the feed with it.
  static Future<Object?> _try(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      return e;
    } on Object {
      return ApiException('Could not reach the marketplace catalogue.');
    }
  }

  static String _bannerSubtitle(Map<String, dynamic> product) {
    final price = product['price'];
    if (price is num && price > 0) return 'Now available · ${price.toStringAsFixed(0)} RWF';
    return 'Available now on MVEC';
  }

  /// Maps a backend product row onto the mobile model's expected keys.
  static Map<String, dynamic>? _normaliseProduct(Map<String, dynamic> json) {
    if (json.isEmpty) return null;

    final price = _num(json['price']);
    final discountPrice = _num(json['discountPrice']);
    final onSale = discountPrice > 0 && discountPrice < price;
    final gallery = json['gallery'];
    final vendor = json['vendor'];
    final category = json['category'];

    return <String, dynamic>{
      'id': _id(json['id'] ?? json['publicId']),
      'name': json['name']?.toString() ?? '',
      'slug': json['slug']?.toString() ?? '',
      'description':
          json['description']?.toString() ?? json['shortDescription']?.toString() ?? '',
      'price': onSale ? discountPrice : price,
      // The model treats a non-null original price as "on sale" and derives the
      // discount percentage from it, so only pass it when genuinely reduced.
      'originalPrice': onSale ? price : null,
      'stockQuantity': _int(json['stockQuantity']),
      'rating': _num(json['averageRating'] ?? json['rating']),
      'ratingCount': _int(json['reviewCount']),
      'isFeatured': json['isFeatured'] == true || json['featured'] == true,
      'isOnSale': onSale,
      'brand': json['brand']?.toString(),
      'media': <String, dynamic>{
        'mainImage': _imageUrl(json, gallery),
      },
      'category': category is Map
          ? <String, dynamic>{
            'id': _id(category['id']),
            'name': category['name']?.toString(),
          }
          : null,
      'vendor': vendor is Map
          ? <String, dynamic>{
            'id': _id(vendor['id']),
            'name':
                vendor['companyName']?.toString() ??
                vendor['name']?.toString() ??
                vendor['fullName']?.toString() ??
                'MVEC seller',
          }
          : <String, dynamic>{
            'id': _id(json['vendorId']),
            'name': json['vendorName']?.toString() ?? 'MVEC seller',
          },
    };
  }

  static String _imageUrl(Map<String, dynamic> json, dynamic gallery) {
    final direct = json['mainImage']?.toString() ?? json['image']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    if (gallery is List && gallery.isNotEmpty) {
      final first = gallery.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }
    return '';
  }

  static Map<String, dynamic>? _normaliseCategory(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    return <String, dynamic>{
      'id': _id(json['id']),
      'name': json['name']?.toString() ?? '',
      'slug': json['slug']?.toString() ?? '',
      'productCount': _int(json['productCount'] ?? json['product_count']),
      'media': <String, dynamic>{
        'mainImage':
            json['imageUrl']?.toString() ??
            json['image']?.toString() ??
            json['icon']?.toString() ??
            '',
      },
    };
  }

  static Map<String, dynamic>? _normaliseVendor(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    return <String, dynamic>{
      'id': _id(json['id'] ?? json['userId']),
      'name':
          json['businessName']?.toString() ??
          json['companyName']?.toString() ??
          json['name']?.toString() ??
          'MVEC seller',
      'slug': json['slug']?.toString() ?? '',
      'description': json['description']?.toString() ?? '',
      'rating': _num(json['ratingAvg'] ?? json['rating']),
      'reviewCount': _int(json['reviewCount'] ?? json['ratingCount']),
      'productCount': _int(json['productCount']),
      'isVerified': json['isVerified'] == true || json['verified'] == true,
      'isFeatured': json['isFeatured'] == true || json['featured'] == true,
      'media': <String, dynamic>{
        'logo': json['logoUrl']?.toString() ?? json['logo']?.toString() ?? '',
        'banner': json['bannerUrl']?.toString() ?? '',
      },
    };
  }

  static int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  /// Backend ids come back as Mongo ObjectIds, public UUID-ish strings or plain
  /// integers depending on the collection, so they are carried through as text.
  /// Coercing them to `int` collapsed every non-numeric id to `0`, which merged
  /// distinct rows in lists and sent the wrong id to `/cart`.
  static String _id(dynamic v) => v?.toString() ?? '';
}

extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}