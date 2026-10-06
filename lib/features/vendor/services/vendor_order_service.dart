import '../../../core/api_client.dart';
import '../models/vendor_order.dart';

/// Contract for the vendor's order data source.
///
/// The UI talks to this interface only, so [ApiVendorOrderService] (the live
/// backend) can be swapped for a test double without touching a screen.
///
/// Every method throws on failure so the Riverpod layer can surface a message;
/// the screens render the error state with a retry.
abstract class VendorOrderService {

  /// Orders assigned to the signed-in vendor, newest first, with per-status
  /// counts for the filter tabs.
  Future<VendorOrderPage> orders({VendorOrderStatus? status, String search = ''});

  /// Single order by id or human order number.
  Future<VendorOrder> order(String id);

  /// Moves an order to [status]. [trackingCode] is required to move into
  /// [VendorOrderStatus.shipped]; [deliveryOtp] is required to move into
  /// [VendorOrderStatus.delivered], which is what releases escrow.
  Future<VendorOrder> updateStatus(
    String id,
    VendorOrderStatus status, {
    String? trackingCode,
    String? courierName,
    String? deliveryOtp,
  });

  /// Cancels an order, refunding the buyer and returning the goods to stock.
  Future<VendorOrder> cancel(String id, {String? reason});
}

/// The two guarded status transitions, checked before the request is sent.
///
/// Shipping without a tracking code and confirming delivery without the buyer's
/// OTP are the steps that commit real money movement, so they are validated here
/// for an immediate, specific message. The backend re-validates both regardless.
/// Exposed as a free function so the rules are testable without a network.
void validateStatusChange(
  VendorOrderStatus status, {
  String? trackingCode,
  String? deliveryOtp,
}) {
  final hasTracking = trackingCode != null && trackingCode.trim().isNotEmpty;
  final hasOtp = deliveryOtp != null && deliveryOtp.trim().isNotEmpty;

  if (status == VendorOrderStatus.shipped && !hasTracking) {
    throw ApiException('Add the courier tracking code before marking shipped.');
  }
  if (status == VendorOrderStatus.delivered && !hasOtp) {
    throw ApiException(
      "Confirm delivery with the buyer's one-time code to release escrow.",
    );
  }
}

/// Orders plus the counts that drive the filter tabs.
class VendorOrderPage {
  const VendorOrderPage({required this.orders, this.counts = const {}});

  final List<VendorOrder> orders;

  /// How many orders sit in each status, so tabs can render `"Pending 3"`.
  /// Always includes a `null` key for the unfiltered total.
  final Map<VendorOrderStatus?, int> counts;

  int get total => counts[null] ?? orders.length;
}

/// Talks to the platform's order API.
class ApiVendorOrderService implements VendorOrderService {
  ApiVendorOrderService(this._api);
  final ApiClient _api;

  @override
  Future<VendorOrderPage> orders({VendorOrderStatus? status, String search = ''}) async {
    final res = await _api.get('/stores/mine/orders', query: {
      'page': 1,
      'limit': 50,
      if (status != null) 'status': status.slug,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    final list = listJson(res, ['orders', 'data']).map(VendorOrder.fromJson).toList();
    return VendorOrderPage(
      orders: list,
      counts: {
        for (final s in VendorOrderStatus.values) s: list.where((o) => o.status == s).length,
        null: list.length,
      },
    );
  }

  @override
  Future<VendorOrder> order(String id) async {
    final res = await _api.get('/stores/mine/orders/$id');
    return VendorOrder.fromJson(singleJson(res, ['order']));
  }

  /// Moves an order forward.
  ///
  /// The two guarded transitions are enforced here rather than left to a failed
  /// request: shipping without a tracking code and confirming delivery without
  /// the buyer's OTP are the two steps that commit real money movement, so the
  /// vendor gets an immediate, specific message instead of a generic API error.
  /// The backend re-validates both regardless.
  @override
  Future<VendorOrder> updateStatus(
    String id,
    VendorOrderStatus status, {
    String? trackingCode,
    String? courierName,
    String? deliveryOtp,
  }) async {
    validateStatusChange(status, trackingCode: trackingCode, deliveryOtp: deliveryOtp);

    final res = await _api.patch('/stores/mine/orders/$id/status', body: {
      'status': status.slug,
      if (trackingCode != null && trackingCode.trim().isNotEmpty) 'trackingCode': trackingCode.trim(),
      if (courierName != null && courierName.trim().isNotEmpty) 'courierName': courierName.trim(),
      if (deliveryOtp != null && deliveryOtp.trim().isNotEmpty) 'deliveryOtp': deliveryOtp.trim(),
    });
    return VendorOrder.fromJson(singleJson(res, ['order']));
  }

  @override
  Future<VendorOrder> cancel(String id, {String? reason}) async {
    final res = await _api.post('/stores/mine/orders/$id/cancel', body: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return VendorOrder.fromJson(singleJson(res, ['order']));
  }
}
