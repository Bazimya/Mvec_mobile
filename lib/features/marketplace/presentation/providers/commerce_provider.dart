import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../models/cart_item.dart';
import '../../../../models/product.dart';
import '../../data/services/api_cart_service.dart';

/// The shopper's cart backend.
///
/// Production always resolves to the live `/cart` endpoints. Tests override
/// this provider to serve fixtures instead of dialling a server.
final cartServiceProvider = Provider<ApiCartService>(
  (ref) => ApiCartService(ref.watch(apiProvider)),
);

/// The storefront cart/wishlist state.
///
/// Exposed as a Riverpod provider so the data source stays substitutable, then
/// handed to the `provider` package binding in `MvecApp` so screens can keep
/// reading it as a plain [ChangeNotifier].
final commerceProviderProvider = Provider<CommerceProvider>(
  (ref) => CommerceProvider(cartService: ref.watch(cartServiceProvider)),
);

/// Cart and wishlist state for the storefront.
///
/// The cart lives on the MVEC backend through [ApiCartService] - the same
/// `/cart` endpoints the web storefront uses - so a cart built in the app is
/// the cart checkout reads. Every mutating call updates the local list from the
/// server response, which keeps quantity limits and stock in sync with the
/// backend rather than trusting the device.
///
/// The wishlist is device-local because the web app keeps it in local storage;
/// it holds products the shopper actually chose, not seeded data.
class CommerceProvider extends ChangeNotifier {
  CommerceProvider({ApiCartService? cartService})
    : _cartService = cartService ?? ApiCartService();

  final ApiCartService _cartService;

  final List<Product> _wishlistItems = [];
  final List<CartItem> _cartItems = [];

  bool _isCartSyncing = false;
  String? _cartError;

  List<Product> get wishlistItems => _wishlistItems;
  List<CartItem> get cartItems => _cartItems;

  /// True while a cart write is in flight, so the UI can disable its controls
  /// instead of letting a shopper queue conflicting updates.
  bool get isCartSyncing => _isCartSyncing;

  /// Last cart failure, cleared on the next successful call.
  String? get cartError => _cartError;

  /// Loads the signed-in shopper's server cart. Safe to call repeatedly.
  Future<void> loadCart() async {
    await _sync(_cartService.getCart);
  }

  bool isWishlisted(Product product) =>
      _wishlistItems.any((item) => item.id == product.id);

  void toggleWishlist(Product product) {
    if (isWishlisted(product)) {
      _wishlistItems.removeWhere((item) => item.id == product.id);
    } else {
      _wishlistItems.add(product);
    }
    notifyListeners();
  }

  void removeFromWishlist(Product product) {
    _wishlistItems.removeWhere((item) => item.id == product.id);
    notifyListeners();
  }

  /// Adds [product] to the server cart.
  ///
  /// The call is awaited so the caller can react to a rejection; the UI's
  /// optimistic local add happens through [_sync]'s server response instead.
  Future<void> addToCart(Product product, {int quantity = 1}) async {
    _wishlistItems.removeWhere((item) => item.id == product.id);
    notifyListeners();
    await _sync(() => _cartService.add(product.id, quantity: quantity));
  }

  void moveToCart(Product product) => addToCart(product);

  /// Sets the quantity of the line holding [item].
  ///
  /// This previously only called `notifyListeners()`, so the stepper moved but
  /// the cart never changed. It now writes through to the backend.
  Future<void> updateCartQuantity(CartItem item, [int? quantity]) async {
    final next = quantity ?? item.quantity + 1;
    await _sync(() => _cartService.updateQuantity(item.product.id, next));
  }

  Future<void> setCartQuantity(CartItem item, int quantity) async {
    await _sync(() => _cartService.updateQuantity(item.product.id, quantity));
  }

  Future<void> removeCartItem(CartItem item) =>
      _sync(() => _cartService.remove(item.product.id));

  /// Empties the server cart, called once checkout has created the order.
  Future<void> clearCart() async {
    try {
      await _cartService.clear();
      _cartError = null;
    } on ApiException catch (e) {
      _cartError = e.message;
    }
    _cartItems.clear();
    notifyListeners();
  }

  /// Runs a cart mutation and replaces the local list with what the backend
  /// returned, so quantities and prices always come from the server.
  /// Drops the locally held cart without touching the backend.
  ///
  /// Used on sign-out: the cart belongs to the session that just ended, so it
  /// must not leak into the next account, but calling `DELETE /cart` would
  /// destroy a cart the user may want back when they sign in again.
  void resetLocalCart() {
    _cartItems.clear();
    _cartError = null;
    _isCartSyncing = false;
    notifyListeners();
  }

  Future<void> _sync(Future<List<CartLine>> Function() action) async {
    _isCartSyncing = true;
    _cartError = null;
    notifyListeners();

    try {
      final lines = await action();
      _cartItems
        ..clear()
        ..addAll(lines.map(_toCartItem));
    } on ApiException catch (e) {
      _cartError = e.message;
    } finally {
      _isCartSyncing = false;
      notifyListeners();
    }
  }

  CartItem _toCartItem(CartLine line) => CartItem(
    product: Product.fromJson(line.toLegacyProductJson()),
    quantity: line.quantity,
  );
}