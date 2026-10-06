import '../../../../core/api_client.dart';

/// One cart line as the backend returns it.
///
/// `GET /cart` answers with `{cart: {items: [...]}}`; each item carries the
/// product snapshot plus the line's own `quantity` and `price`.
class CartLine {
  const CartLine({
    required this.productId,
    required this.quantity,
    required this.productJson,
  });

  final String productId;
  final int quantity;

  /// Raw product snapshot, so the UI can render name/price/image without a
  /// second round trip. The legacy `models/Product` shape is derived from it
  /// by [toLegacyProductJson].
  final Map<String, dynamic> productJson;

  double get price => _double(productJson['price'] ?? productJson['discountPrice']);

  double get totalPrice => price * quantity;

  /// Maps this line onto the flat product shape the existing cart/wishlist
  /// widgets read (`id`, `name`, `price`, `images`, `vendor`, ...).
  Map<String, dynamic> toLegacyProductJson() {
    final product = productJson;
    final media = product['media'];
    final vendor = product['vendor'];
    final category = product['category'];
    final gallery = product['gallery'];

    String image = '';
    if (media is Map) {
      image = media['mainImage']?.toString() ?? '';
    } else if (media is List && media.isNotEmpty) {
      image = media.first?.toString() ?? '';
    }
    if (image.isEmpty && gallery is List && gallery.isNotEmpty) {
      image = gallery.first?.toString() ?? '';
    }
    if (image.isEmpty) {
      image = product['mainImage']?.toString() ?? product['image']?.toString() ?? '';
    }

    final rawPrice = _double(product['price']);
    final discountPrice = _double(product['discountPrice']);
    final activePrice =
        discountPrice > 0 && discountPrice < rawPrice ? discountPrice : rawPrice;

    return <String, dynamic>{
      'id': '${product['_id'] ?? product['id'] ?? product['publicId'] ?? ''}',
      'name': product['name']?.toString() ?? '',
      'description': product['description']?.toString() ?? '',
      'price': activePrice,
      'oldPrice': discountPrice > 0 && discountPrice < rawPrice ? rawPrice : null,
      'stock': _int(product['stockQuantity']),
      'images': <String>[if (image.isNotEmpty) image],
      'colors': _stringList(product['colors'] ?? product['color']),
      'sizes': _stringList(product['sizes'] ?? product['size']),
      'vendor': <String, dynamic>{
        'id': '${vendor is Map ? (vendor['id'] ?? '') : (product['vendorId'] ?? '')}',
        'name': vendor is Map
            ? (vendor['companyName'] ?? vendor['name'] ?? vendor['fullName'] ?? 'MVEC seller')
                .toString()
            : 'MVEC seller',
        'logo': vendor is Map ? (vendor['logo'] ?? vendor['logoUrl'] ?? '').toString() : '',
        'rating': _double(vendor is Map ? (vendor['rating'] ?? vendor['ratingAvg']) : 0),
        'totalProducts': _int(vendor is Map ? vendor['productCount'] : 0),
      },
      'categoryId': category is Map ? category['id'] : product['categoryId'],
      'categoryName': category is Map ? category['name']?.toString() : null,
    };
  }

  /// True when the line's product can still be ordered at this quantity.
  bool get inStock => quantity > 0;
}

/// Talks to the platform's cart API.
///
/// The web storefront drives the same endpoints through `MarketplaceContext`,
/// so a cart created here is the same cart the web checkout reads.
class ApiCartService {
  ApiCartService([ApiClient? api]) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// Signed-in shopper's cart, empty when the backend has nothing stored.
  Future<List<CartLine>> getCart() async {
    final json = await _api.get('/cart');
    return _parseCart(json);
  }

  /// Adds [quantity] of [productId], merging into an existing line when the
  /// product is already in the cart. Returns the refreshed cart.
  Future<List<CartLine>> add(String productId, {int quantity = 1}) async {
    final json = await _api.post(
      '/cart',
      body: <String, dynamic>{'productId': productId, 'quantity': quantity},
    );
    return _parseCart(json);
  }

  /// Sets the line quantity for [productId]. The backend clamps at 1, matching
  /// the web `Math.max(1, qty)` guard.
  Future<List<CartLine>> updateQuantity(String productId, int quantity) async {
    final json = await _api.put(
      '/cart/items/$productId',
      body: <String, dynamic>{'quantity': quantity < 1 ? 1 : quantity},
    );
    return _parseCart(json);
  }

  Future<List<CartLine>> remove(String productId) async {
    final json = await _api.delete('/cart/items/$productId');
    return _parseCart(json);
  }

  Future<void> clear() async {
    await _api.delete('/cart');
  }

  /// Reads the cart out of any of the envelopes the API returns: `{cart:{items}}`
  /// on success, or the bare cart on some verbs.
  List<CartLine> _parseCart(dynamic json) {
    Map<String, dynamic>? cart;
    if (json is Map) {
      final raw = json['cart'];
      if (raw is Map) {
        cart = Map<String, dynamic>.from(raw);
      } else {
        cart = Map<String, dynamic>.from(json);
      }
    }

    final rawItems = cart?['items'];
    if (rawItems is! List) return const <CartLine>[];

    final lines = <CartLine>[];
    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final product = entry['product'];
      // A line with no embedded product snapshot (e.g. a pruned catalogue entry)
      // still identifies itself, so keep it rather than dropping the quantity.
      final productJson =
          product is Map ? Map<String, dynamic>.from(product) : <String, dynamic>{};
      final productId =
          entry['productId']?.toString() ??
          (productJson['_id'] ?? productJson['id'] ?? '').toString();
      if (productId.isEmpty) continue;

      final quantity = _int(entry['quantity'] ?? entry['qty']);
      final line = CartLine(
        productId: productId,
        quantity: quantity < 1 ? 1 : quantity,
        productJson: productJson.isEmpty
            ? <String, dynamic>{'id': productId}
            : productJson,
      );
      // The backend may price the line separately from the product snapshot.
      if (entry['price'] != null && !line.productJson.containsKey('price')) {
        line.productJson['price'] = entry['price'];
      }
      lines.add(line);
    }
    return lines;
  }
}

int _int(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));

double _double(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  final text = value?.toString() ?? '';
  return text.isEmpty ? const <String>[] : <String>[text];
}
