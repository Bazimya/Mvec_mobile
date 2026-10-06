import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';

/// Status the backend reports for an order, as used by the buyer's order list.
enum BuyerOrderStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  processing('PROCESSING'),
  shipped('SHIPPED'),
  outForDelivery('OUT_FOR_DELIVERY'),
  delivered('DELIVERED'),
  cancelled('CANCELLED'),
  unknown('');

  const BuyerOrderStatus(this.wire);

  /// The value the backend sends.
  final String wire;

  /// Human-readable form for the buyer's order list, where the wire enum
  /// (PROCESSING) would read as jargon.
  String get label => switch (this) {
    BuyerOrderStatus.pending => 'Pending',
    BuyerOrderStatus.confirmed => 'Confirmed',
    BuyerOrderStatus.processing => 'Processing',
    BuyerOrderStatus.shipped => 'Shipped',
    BuyerOrderStatus.outForDelivery => 'Out for delivery',
    BuyerOrderStatus.delivered => 'Delivered',
    BuyerOrderStatus.cancelled => 'Cancelled',
    BuyerOrderStatus.unknown => 'Unknown',
  };

  /// Orders still being worked on; the buyer sees these under "Active".
  bool get isActive =>
      this != BuyerOrderStatus.delivered &&
      this != BuyerOrderStatus.cancelled &&
      this != BuyerOrderStatus.unknown;

  static BuyerOrderStatus parse(dynamic value) {
    final text = value?.toString().trim().toUpperCase() ?? '';
    return BuyerOrderStatus.values.firstWhere(
      (status) => status.wire == text,
      orElse: () => BuyerOrderStatus.unknown,
    );
  }
}

/// A buyer order row, normalised from `GET /orders/my-orders`.
class BuyerOrder {
  const BuyerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.itemCount,
    required this.createdAt,
    required this.itemNames,
  });

  final String id;
  final String orderNumber;
  final BuyerOrderStatus status;
  final String paymentStatus;
  final double total;
  final int itemCount;
  final DateTime? createdAt;

  /// First few product names, for the card's summary line. Only ever names the
  /// shopper's own purchases.
  final List<String> itemNames;

  bool get isPaid => paymentStatus.trim().toUpperCase() == 'PAID';

  /// Display string for the order date, empty when the backend omitted it.
  String get dateLabel => createdAt == null ? '' : _formatDate(createdAt!);

  static String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = value.month >= 1 && value.month <= 12
        ? months[value.month - 1]
        : '${value.month}';
    return '$month ${value.day}, ${value.year}';
  }
}

/// Talks to the buyer's order and payment endpoints.
///
/// Mirrors `ordersApi` and `paymentsApi` in the web frontend: checkout creates
/// the order from the server-side cart, then payment is initiated against the
/// returned order id. Nothing here fabricates an order - if the backend does not
/// create one, the flow stops with the backend's message.
/// The signed-in shopper's orders backend.
///
/// Production resolves to the live `/orders/my-orders` routes; tests override
/// this provider so the orders screen can be driven without a network.
final buyerOrderServiceProvider = Provider<ApiOrderService>(
  (ref) => ApiOrderService(ref.watch(apiProvider)),
);

class ApiOrderService {
  ApiOrderService([ApiClient? api]) : _api = api ?? ApiClient.instance;

  /// Window the backend allows a paid order to be cancelled, mirroring the web
  /// `CANCEL_WINDOW_MS`.
  static const cancelWindow = Duration(minutes: 30);

  final ApiClient _api;

  /// The signed-in shopper's orders, newest first.
  Future<List<BuyerOrder>> myOrders() async {
    final json = await _api.get('/orders/my-orders');
    final rows = json is Map ? json['orders'] : null;
    if (rows is! List) return const <BuyerOrder>[];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => _parse(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Single order by id, used for payment status polling.
  Future<BuyerOrder> order(String id) async {
    final json = await _api.get('/orders/$id');
    final row = singleJson(json, const ['order']);
    return _parse(row);
  }

  /// Creates an order from the server-side cart.
  ///
  /// [shippingAddress] keys mirror the web checkout form: `street`, `city`,
  /// `state`, `country`, `postalCode`. Returns the new order id.
  Future<BuyerOrder> checkout({
    required Map<String, String> shippingAddress,
    required String paymentMethod,
  }) async {
    final json = await _api.post(
      '/orders/checkout',
      body: <String, dynamic>{
        'shippingAddress': _addressPayload(shippingAddress),
        'paymentMethod': _paymentCode(paymentMethod),
      },
    );
    final row = singleJson(json, const ['order']);
    final order = _parse(row);
    if (order.id.isEmpty) {
      throw ApiException('Checkout did not return an order.');
    }
    return order;
  }

  /// Cancels an order that is still inside the cancellation window.
  Future<BuyerOrder> cancel(String id) async {
    final json = await _api.patch('/orders/$id/cancel');
    return _parse(singleJson(json, const ['order']));
  }

  /// Starts a mobile money payment for [orderId].
  ///
  /// The backend replies asynchronously (the shopper approves a USSD prompt),
  /// so this returning means "prompt sent", not "paid". Callers poll [order] for
  /// the confirmed status.
  Future<void> initiateMobileMoney({
    required String orderId,
    required String phoneNumber,
  }) async {
    await _api.post(
      '/payments/momo/initiate',
      body: <String, dynamic>{
        'orderId': orderId,
        'phoneNumber': phoneNumber,
      },
    );
  }

  /// Starts the alternative K-Pay mobile money rail.
  Future<void> initiateKpayMobileMoney({
    required String orderId,
    required String phoneNumber,
  }) async {
    await _api.post(
      '/payments/kpay/momo/initiate',
      body: <String, dynamic>{
        'orderId': orderId,
        'phoneNumber': phoneNumber,
      },
    );
  }

  /// Starts a K-Pay card payment. Returns a redirect URL when the backend hands
  /// one back, in which case the caller must open it to finish payment.
  Future<String?> initiateKpayCard(String orderId) async {
    final json = await _api.post(
      '/payments/kpay/card/initiate',
      body: <String, dynamic>{'orderId': orderId},
    );
    if (json is Map) {
      final url = json['redirectUrl'] ?? json['redirect_url'];
      if (url != null && url.toString().isNotEmpty) return url.toString();
    }
    return null;
  }

  /// True while the shopper is still allowed to cancel [order]: before the
  /// order ships, and within 30 minutes of payment.
  bool canCancel(BuyerOrder order) {
    if (!const <BuyerOrderStatus>{
      BuyerOrderStatus.pending,
      BuyerOrderStatus.confirmed,
      BuyerOrderStatus.processing,
    }.contains(order.status)) {
      return false;
    }
    if (!order.isPaid) return true;
    final createdAt = order.createdAt;
    if (createdAt == null) return true;
    return DateTime.now().difference(createdAt) <= cancelWindow;
  }

  static Map<String, dynamic> _addressPayload(Map<String, String> address) =>
      <String, dynamic>{
        'street': address['street'] ?? address['address'] ?? '',
        'city': address['city'] ?? address['district'] ?? '',
        'state': address['state'] ?? address['province'] ?? '',
        'country': address['country'] ?? 'Rwanda',
        'postalCode': address['postalCode'] ?? '',
      };

  /// Maps the checkout page's display labels onto the backend's enum values,
  /// matching the web `paymentMap`.
  static String _paymentCode(String method) => switch (method.trim().toLowerCase()) {
    'card' || 'credit / debit card' || 'credit or debit card' => 'CARD',
    'airtel' || 'airtel money' => 'AIRTEL',
    'kpay momo' || 'kpay mobile money' => 'MOMO',
    'cash on delivery' || 'cash' || 'cod' => 'CASH_ON_DELIVERY',
    _ => 'MOMO',
  };

  static BuyerOrder _parse(Map<String, dynamic> json) {
    final items = json['items'];
    final names = <String>[];
    var itemCount = 0;
    if (items is List) {
      itemCount = items.length;
      for (final entry in items.take(3)) {
        if (entry is Map) {
          final name = entry['name']?.toString() ?? entry['productName']?.toString();
          if (name != null && name.isNotEmpty) names.add(name);
        }
      }
    }

    return BuyerOrder(
      id: '${json['id'] ?? ''}',
      orderNumber:
          json['orderNumber']?.toString() ?? '#${json['id'] ?? 'order'}',
      status: BuyerOrderStatus.parse(json['orderStatus'] ?? json['status']),
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      total: _double(json['totalAmount'] ?? json['total']),
      // The backend does not always send a count, so derive it from the lines.
      itemCount: _int(json['itemCount'] ?? json['totalItems']) == 0
          ? itemCount
          : _int(json['itemCount'] ?? json['totalItems']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      itemNames: names,
    );
  }

  static int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));

  static double _double(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
}