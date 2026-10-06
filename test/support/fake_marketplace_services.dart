// Shared test doubles for the marketplace data sources.
//
// The app now reads `/products`, `/categories`, `/vendors` and `/cart` from the
// live MVEC backend, so widget tests must inject a stand-in data source instead
// of relying on bundled demo rows. The payloads below deliberately use the
// *backend* dialect (nested `media`, `stockQuantity`, `companyName`) so the
// tests exercise the same normalising code paths production uses.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mvec_mobile/features/marketplace/data/services/api_cart_service.dart';
import 'package:mvec_mobile/features/marketplace/data/services/api_order_service.dart';
import 'package:mvec_mobile/features/marketplace/data/services/home_service.dart';
import 'package:mvec_mobile/features/marketplace/presentation/providers/commerce_provider.dart';
import 'package:mvec_mobile/features/marketplace/presentation/providers/home_provider.dart';
import 'package:mvec_mobile/models/cart_item.dart';
import 'package:mvec_mobile/models/product.dart';

/// A product exactly as `GET /products` returns it.
Map<String, dynamic> fixtureProductJson({
  required String id,
  required String name,
  required double price,
  int stock = 42,
  double? originalPrice,
  String categoryId = 'c-1',
  String categoryName = 'Electronics',
  String? vendorId,
  String? vendorName,
  List<String> badges = const <String>[],
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'slug': name.toLowerCase().replaceAll(' ', '-'),
  'description': '$name, a fixture product standing in for a live catalogue row.',
  'price': price,
  if (originalPrice != null) 'originalPrice': originalPrice,
  'discountPrice': price,
  'stockQuantity': stock,
  'rating': 4.5,
  'numReviews': 12,
  'badges': badges,
  'media': <String, dynamic>{
    'mainImage': 'https://example.test/$id.png',
    'gallery': <String>['https://example.test/$id-1.png'],
  },
  'category': <String, dynamic>{'id': categoryId, 'name': categoryName},
  if (vendorId != null)
    'vendor': <String, dynamic>{
      'id': vendorId,
      'companyName': vendorName ?? 'Fixture Vendor',
    },
};

/// The three products the storefront tests assert on by name.
final fixtureProducts = <Map<String, dynamic>>[
  fixtureProductJson(
    id: 'p-1',
    name: 'Wireless Over-Ear Headphones',
    price: 129000,
    vendorId: 'v-1',
    vendorName: 'Umucyo Electronics',
  ),
  fixtureProductJson(
    id: 'p-2',
    name: 'Gaming Mechanical Keyboard',
    price: 85000,
    originalPrice: 110000,
    vendorId: 'v-1',
    vendorName: 'Umucyo Electronics',
    badges: const ['best-seller'],
  ),
  fixtureProductJson(
    id: 'p-3',
    name: 'Linen Summer Dress',
    price: 42000,
    categoryId: 'c-2',
    categoryName: 'Fashion',
    vendorId: 'v-2',
    vendorName: 'Nyamasheke Textiles',
  ),
];

final fixtureCategories = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'c-1',
    'name': 'Electronics',
    'slug': 'electronics',
    'productCount': 2,
    'media': <String, dynamic>{'mainImage': 'https://example.test/c-1.png'},
  },
  <String, dynamic>{
    'id': 'c-2',
    'name': 'Fashion',
    'slug': 'fashion',
    'productCount': 1,
    'media': <String, dynamic>{'mainImage': 'https://example.test/c-2.png'},
  },
  <String, dynamic>{
    'id': 'c-3',
    'name': 'Home & Garden',
    'slug': 'home-and-garden',
    'productCount': 0,
    'media': <String, dynamic>{'mainImage': 'https://example.test/c-3.png'},
  },
];

final fixtureVendors = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'v-1',
    'name': 'Umucyo Electronics',
    'slug': 'umucyo-electronics',
    'description': 'Rwandan consumer electronics.',
    'rating': 4.6,
    'reviewCount': 88,
    'productCount': 2,
    'logo_url': 'https://example.test/v-1.png',
  },
  <String, dynamic>{
    'id': 'v-2',
    'name': 'Nyamasheke Textiles',
    'slug': 'nyamasheke-textiles',
    'description': 'Locally woven textiles.',
    'rating': 4.3,
    'reviewCount': 41,
    'productCount': 1,
    'logo_url': 'https://example.test/v-2.png',
  },
];

/// The payload [FakeHomeService] hands back, shaped like the real
/// `ApiHomeService.getHomeFeed()` output.
Map<String, dynamic> fixtureHomeFeedJson() => <String, dynamic>{
  'banners': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'title': 'Wireless Over-Ear Headphones',
      'subtitle': 'Sound that travels',
      'media': <String, dynamic>{'mainImage': 'https://example.test/p-1.png'},
    },
  ],
  'categories': fixtureCategories,
  'featuredVendors': fixtureVendors,
  'featuredProducts': fixtureProducts.take(2).toList(),
  'recommendedProducts': fixtureProducts.skip(2).toList(),
  'products': fixtureProducts,
  // The For You tab only renders its "Recently Viewed" rail when there is
  // history, so the fixture carries one product.
  'recentlyViewed': <Map<String, dynamic>>[fixtureProducts.first],
};

/// Stands in for [ApiHomeService] so the storefront renders the fixture
/// catalogue without a backend.
class FakeHomeService implements HomeService {
  FakeHomeService({Map<String, dynamic>? feed, this.error})
    : feed = feed ?? fixtureHomeFeedJson();

  final Map<String, dynamic> feed;

  /// When set, [getHomeFeed] throws it instead of serving [feed], so error
  /// states can be exercised.
  final Object? error;

  @override
  bool get isDemo => false;

  @override
  Future<Map<String, dynamic>> getHomeFeed() async {
    if (error != null) throw error!;
    return feed;
  }
}

/// Stands in for [ApiCartService], keeping cart lines in memory so the cart UI
/// can be driven without `/cart` round trips.
class FakeCartService implements ApiCartService {
  FakeCartService({List<CartLine>? lines}) : _lines = List.of(lines ?? const []);

  final List<CartLine> _lines;

  /// Every mutation the UI issued, in order, for assertions.
  final List<String> calls = <String>[];

  @override
  Future<List<CartLine>> getCart() async {
    calls.add('getCart');
    return List.unmodifiable(_lines);
  }

  @override
  Future<List<CartLine>> add(String productId, {int quantity = 1}) async {
    calls.add('add($productId,$quantity)');
    final existing = _lines.indexWhere((line) => line.productId == productId);
    if (existing >= 0) {
      final line = _lines[existing];
      _lines[existing] = CartLine(
        productId: line.productId,
        quantity: line.quantity + quantity,
        productJson: line.productJson,
      );
    } else {
      _lines.add(
        CartLine(
          productId: productId,
          quantity: quantity,
          productJson: _productJsonFor(productId),
        ),
      );
    }
    return List.unmodifiable(_lines);
  }

  @override
  Future<List<CartLine>> updateQuantity(String productId, int quantity) async {
    calls.add('update($productId,$quantity)');
    final index = _lines.indexWhere((line) => line.productId == productId);
    if (index < 0) return List.unmodifiable(_lines);
    if (quantity <= 0) {
      _lines.removeAt(index);
      return List.unmodifiable(_lines);
    }
    _lines[index] = CartLine(
      productId: productId,
      quantity: quantity,
      productJson: _lines[index].productJson,
    );
    return List.unmodifiable(_lines);
  }

  @override
  Future<List<CartLine>> remove(String productId) async {
    calls.add('remove($productId)');
    _lines.removeWhere((line) => line.productId == productId);
    return List.unmodifiable(_lines);
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    _lines.clear();
  }

  /// Reuses the fixture product with [productId] so the cart row can render a
  /// name and price, falling back to the first fixture product.
  Map<String, dynamic> _productJsonFor(String productId) {
    final matches = fixtureProducts.where(
      (product) => product['id'] == productId,
    );
    return matches.isEmpty ? fixtureProducts.first : matches.first;
  }
}

/// Builds a [Product] the cart tests can add directly.
Product fixtureProduct({
  String id = 'p-1',
  String name = 'Wireless Over-Ear Headphones',
  double price = 129000,
  int stock = 42,
}) => Product(
  id: id,
  name: name,
  description: 'A fixture product.',
  price: price,
  stock: stock,
  images: <String>['https://example.test/$id.png'],
  colors: const <String>[],
  sizes: const <String>[],
  vendor: Vendor.empty(),
);

/// Builds a [CartItem] for cart-widget assertions.
CartItem fixtureCartItem({
  String id = 'p-1',
  String name = 'Wireless Over-Ear Headphones',
  double price = 129000,
  int quantity = 1,
}) => CartItem(
  product: fixtureProduct(id: id, name: name, price: price),
  quantity: quantity,
);

/// Stands in for [ApiOrderService] so the orders screen renders fixtures
/// instead of calling `/orders/my-orders`.
class FakeOrderService extends ApiOrderService {
  FakeOrderService({List<BuyerOrder>? orders})
    : orders = orders ?? defaultFixtureOrders;

  final List<BuyerOrder> orders;

  @override
  Future<List<BuyerOrder>> myOrders() async => List.unmodifiable(orders);
}

/// Two orders: one still in progress, one delivered, so both tabs have content.
final defaultFixtureOrders = <BuyerOrder>[
  BuyerOrder(
    id: 'o-1',
    orderNumber: 'MVEC-1001',
    status: BuyerOrderStatus.processing,
    paymentStatus: 'PAID',
    total: 214000,
    itemCount: 2,
    createdAt: DateTime(2026, 3, 2),
    itemNames: const <String>[
      'Wireless Over-Ear Headphones',
      'Gaming Mechanical Keyboard',
    ],
  ),
  BuyerOrder(
    id: 'o-2',
    orderNumber: 'MVEC-0998',
    status: BuyerOrderStatus.delivered,
    paymentStatus: 'PAID',
    total: 42000,
    itemCount: 1,
    createdAt: DateTime(2026, 2, 20),
    itemNames: const <String>['Linen Summer Dress'],
  ),
];

/// The Riverpod overrides every storefront test needs: a fixture home feed, an
/// in-memory cart and fixture orders. Spread them into the `ProviderScope` that
/// boots `MvecApp`.
List<Override> marketplaceOverrides({
  FakeHomeService? home,
  FakeCartService? cart,
  FakeOrderService? orders,
}) => <Override>[
  homeServiceProvider.overrideWithValue(home ?? FakeHomeService()),
  cartServiceProvider.overrideWithValue(cart ?? FakeCartService()),
  buyerOrderServiceProvider.overrideWithValue(orders ?? FakeOrderService()),
];
