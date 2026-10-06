import '../core/api_client.dart';
import '../models/catalog.dart';

/// Delivery-partner API calls.
///
/// Every method here maps one-to-one onto a route the web frontend already
/// uses, so the mobile delivery role consumes the same backend records rather
/// than a parallel mobile-only dataset.
class DeliveryService {
  DeliveryService(this._api);
  final ApiClient _api;

  /// `GET /orders/deliverable` — the paid orders MVEC is holding funds for
  /// until the buyer hands over the six-digit delivery OTP. This is the
  /// delivery partner's real work queue.
  Future<List<OrderRecord>> deliverableOrders() async {
    final res = await _api.get('/orders/deliverable');
    return listJson(res, ['orders', 'data']).map(OrderRecord.fromJson).toList();
  }

  /// `GET /orders` — orders visible to this account, used to derive the
  /// delivery history the backend does not expose as a dedicated endpoint.
  Future<List<OrderRecord>> orders() async {
    final res = await _api.get('/orders');
    return listJson(res, ['orders', 'data']).map(OrderRecord.fromJson).toList();
  }

  /// `PATCH /orders/:id/deliver` — confirm delivery with the buyer's OTP.
  /// On success the backend releases the protected settlement to the seller,
  /// so this single call is what links the delivery record to the order, the
  /// vendor payout and the financial ledger.
  Future<void> confirmDelivery(String orderId, String otp) async {
    await _api.patch('/orders/$orderId/deliver', body: {'deliveryOtp': otp});
  }
}
