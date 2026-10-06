import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/catalog.dart';
import '../models/vendor.dart';
import '../models/vendor_product.dart';

/// Vendor-facing API calls.
///
/// Every endpoint here is scoped to the signed-in vendor's own store
/// (`/stores/mine…`), so none of them need a store id. Mirrors the shape of
/// `AdminService`: the same [ApiClient] is injected, and each method unwraps
/// the backend envelope into a domain model.
class VendorService {
  VendorService(this._api);
  final ApiClient _api;

  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  // ---------- Store profile ----------

  /// The vendor's own store record, or `null` when they have not created one
  /// yet (a 404 is an empty profile, not an error — the setup form needs to
  /// render in that case).
  Future<StoreProfile?> myStore() async {
    try {
      final res = await _api.get('/stores/mine');
      return StoreProfile.fromJson(singleJson(res, ['store']));
    } catch (e) {
      if (statusCodeOf(e) == 404) return null;
      rethrow;
    }
  }

  /// Saves business, contact and address changes. `PUT /stores` — the store is
  /// resolved from the auth token, so no id is sent.
  Future<StoreProfile> updateStore(Map<String, dynamic> body) async {
    final res = await _api.put('/stores', body: body);
    return StoreProfile.fromJson(singleJson(res, ['store']));
  }

  // ---------- Verification ----------

  /// Submits verification documents for review. Each entry is
  /// `{type, url}`; the platform moves the store to `PENDING`.
  Future<StoreProfile> submitDocuments(
    List<Map<String, String>> documents,
  ) async {
    final res = await _api.post(
      '/stores/mine/verification',
      body: {
        'documents': [
          for (final d in documents)
            {
              'type': d['type'] ?? '',
              if (d['url'] != null && d['url']!.trim().isNotEmpty)
                'url': d['url']!.trim(),
            },
        ],
      },
    );
    return StoreProfile.fromJson(singleJson(res, ['store']));
  }

  // ---------- Overview ----------

  /// Headline counters for the dashboard summary cards.
  Future<VendorStats> stats() async {
    final res = await _api.get('/stores/mine/overview');
    return VendorStats.fromJson(singleJson(res, ['overview', 'stats', 'data']));
  }

  /// The unified activity timeline (orders, payouts, inventory adjustments),
  /// filterable by date range and activity family.
  Future<Paged<VendorActivity>> activity({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? type,
  }) async {
    final res = await _api.get(
      '/stores/mine/activity',
      query: {
        'page': page,
        'limit': limit,
        if (from != null) 'from': _day.format(from),
        if (to != null) 'to': _day.format(to),
        if (type != null && type.isNotEmpty && type != 'ALL') 'type': type,
      },
    );
    return Paged.parse(res, VendorActivity.fromJson);
  }

  // ---------- Products ----------

  /// The vendor's catalogue, paginated and searchable server-side.
  Future<Paged<VendorProduct>> products({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    bool? lowStockOnly,
  }) async {
    final res = await _api.get(
      '/stores/mine/products',
      query: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty && status != 'ALL')
          'status': status,
        if (lowStockOnly == true) 'lowStock': true,
      },
    );
    return Paged.parse(res, VendorProduct.fromJson);
  }

  Future<VendorProduct> createProduct(Map<String, dynamic> body) async {
    final res = await _api.post('/stores/mine/products', body: body);
    return VendorProduct.fromJson(singleJson(res, ['product']));
  }

  Future<VendorProduct> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put('/stores/mine/products/$id', body: body);
    return VendorProduct.fromJson(singleJson(res, ['product']));
  }

  /// Flips a listing between `ACTIVE` and `INACTIVE` without touching any
  /// other field — the availability toggle in the product list.
  Future<VendorProduct> setAvailability(String id, String status) async {
    final res = await _api.patch(
      '/stores/mine/products/$id/availability',
      body: {'status': status},
    );
    return VendorProduct.fromJson(singleJson(res, ['product']));
  }

  /// Soft-deletes a listing: the record is flagged removed, keeping its order
  /// history intact, rather than being erased.
  Future<void> removeProduct(String id) async {
    await _api.delete('/stores/mine/products/$id');
  }

  // ---------- Categories ----------

  /// Categories offered in the product form's category picker.
  Future<List<CategoryRecord>> categories() async {
    final res = await _api.get('/categories', query: {'tree': 'false'});
    return listJson(res, [
      'categories',
      'data',
    ]).map(CategoryRecord.fromJson).toList();
  }

  /// Creates a category from inside the product form ("+ Add New Category").
  /// Returns the new category so the picker can select it immediately.
  Future<CategoryRecord> createCategory(String name) async {
    final res = await _api.post('/categories', body: {'name': name.trim()});
    return CategoryRecord.fromJson(singleJson(res, ['category']));
  }

  // ---------- Seller onboarding ----------

  /// `POST /vendors/become-seller` — upgrade the signed-in account to a
  /// seller. The same route the web console's "Become a Seller" page posts to.
  Future<String> becomeSeller({
    required String businessName,
    required String phone,
    required String email,
    String? description,
  }) async {
    final res = await _api.post(
      '/vendors/become-seller',
      body: {
        'businessName': businessName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    final message = res is Map ? res['message'] : null;
    return message is String && message.isNotEmpty
        ? message
        : 'Your seller account is ready';
  }

  // ---------- Payouts ----------
  //
  // These are the exact routes the web console's vendor payout page uses, so the
  // money a vendor sees here is the same balance the platform holds for them.

  /// `GET /payouts/balance` — the vendor's own withdrawable balance.
  Future<VendorPayoutBalance> payoutBalance() async {
    final res = await _api.get('/payouts/balance');
    return VendorPayoutBalance.fromJson(singleJson(res, ['balance', 'data']));
  }

  /// `GET /payouts/history` — the vendor's own payout requests.
  Future<List<PayoutRecord>> payoutHistory() async {
    final res = await _api.get('/payouts/history');
    return listJson(res, [
      'payouts',
      'data',
    ]).map(PayoutRecord.fromJson).toList();
  }

  /// `POST /payouts/request` — ask MVEC to release a payout.
  Future<String> requestPayout({
    required num amount,
    required String accountName,
    required String accountNumber,
  }) async {
    final res = await _api.post(
      '/payouts/request',
      body: {
        'amount': amount,
        'payoutDetails': {
          'accountName': accountName,
          'accountNumber': accountNumber,
        },
      },
    );
    final message = res is Map ? res['message'] : null;
    return message is String && message.isNotEmpty
        ? message
        : 'Payout request submitted';
  }

  // ---------- Wholesale purchases ----------
  //
  // `GET /wholesale/orders/mine` is the supplier-scoped purchase ledger. A
  // vendor browsing it sees their own purchase records only, exactly as the web
  // console does.

  Future<List<WholesaleOrder>> wholesalePurchases() async {
    final res = await _api.get('/wholesale/orders/mine');
    return listJson(res, [
      'orders',
      'wholesaleOrders',
      'data',
    ]).map(WholesaleOrder.fromJson).toList();
  }

  // ---------- Reviews ----------
  //
  // Reviews are only ever read per product (`GET /reviews/product/:id`), so the
  // vendor review page is assembled from the vendor's own products rather than
  // from a vendor-wide endpoint that does not exist.

  Future<List<ReviewRecord>> productReviews(String productId) async {
    final res = await _api.get('/reviews/product/$productId');
    return listJson(res, [
      'reviews',
      'data',
    ]).map(ReviewRecord.fromJson).toList();
  }
}
