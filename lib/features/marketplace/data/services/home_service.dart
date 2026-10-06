/// Contract for the marketplace home feed data source.
///
/// [ApiHomeService] is the production implementation, reading the same
/// `/products`, `/categories` and `/vendors` resources the web storefront uses.
/// Tests inject their own [HomeService] to drive the UI without a network.
abstract class HomeService {
  /// Fetches the home feed payload in a Map structure that mirrors the
  /// backend API response schema (`banners`, `categories`, `products`...).
  ///
  /// Throws an [Exception] when the feed cannot be retrieved.
  Future<Map<String, dynamic>> getHomeFeed();

  /// Whether this service is serving bundled placeholder data rather than the
  /// live catalogue. Always false in production.
  bool get isDemo;
}