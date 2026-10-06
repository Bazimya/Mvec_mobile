import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../models/catalog.dart';
import '../../../../providers/admin_providers.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/delivery_service.dart';

/// Delivery role state, sourced entirely from the live MVEC backend through
/// [DeliveryService].
final deliveryServiceProvider = Provider<DeliveryService>(
  (ref) => DeliveryService(ref.watch(apiProvider)),
);

/// The delivery partner's work queue — paid orders awaiting delivery
/// confirmation.
final deliverableOrdersProvider = FutureProvider.autoDispose<List<OrderRecord>>(
  (ref) async {
    return ref.watch(deliveryServiceProvider).deliverableOrders();
  },
);

/// Deliveries this account has already confirmed.
///
/// The backend exposes no dedicated "my delivered orders" route, so this is
/// derived by filtering the same real order records the API serves. No
/// synthesised rows are introduced.
final deliveryHistoryProvider = FutureProvider.autoDispose<List<OrderRecord>>((
  ref,
) async {
  final all = await ref.watch(deliveryServiceProvider).orders();
  final mine = ref.watch(currentDeliveryUserIdProvider);
  return all
      .where(
        (o) =>
            (o.status ?? '').toUpperCase() == 'DELIVERED' &&
            (mine == null || _matchesDelivery(o, mine)),
      )
      .toList();
});

/// The signed-in delivery account's id, or null when not signed in.
final currentDeliveryUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return user.id;
});

bool _matchesDelivery(OrderRecord order, String userId) {
  final raw = order.raw;
  if (raw == null) return false;
  final courier = raw['deliveryPartner'] ?? raw['courier'] ?? raw['rider'];
  if (courier is Map && courier['_id']?.toString() == userId) return true;
  if (raw['deliveryPartnerId']?.toString() == userId) return true;
  if (raw['courierId']?.toString() == userId) return true;
  return false;
}

/// Confirm delivery with the buyer's six-digit OTP.
final confirmDeliveryProvider =
    Provider<Future<void> Function(String orderId, String otp)>(
      (ref) => (orderId, otp) async {
        await ref.read(deliveryServiceProvider).confirmDelivery(orderId, otp);
        ref.invalidate(deliverableOrdersProvider);
        ref.invalidate(deliveryHistoryProvider);
        ref.invalidate(ordersProvider);
      },
    );
