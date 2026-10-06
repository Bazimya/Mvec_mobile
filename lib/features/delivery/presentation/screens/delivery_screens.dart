import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../models/catalog.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/mv_icon.dart';
import '../providers/delivery_providers.dart';

/// The delivery milestone ladder shared by the dashboard and My Deliveries.
/// Mirrors `STEPS` in the web frontend's `components/DeliveryTracking.jsx`.
const List<String> deliverySteps = <String>[
  'PENDING',
  'CONFIRMED',
  'PROCESSING',
  'READY_FOR_SHIPMENT',
  'SHIPPED',
  'DELIVERED',
];

/// Human labels for the milestone ladder, preserving the web terminology.
const Map<String, String> deliveryStepLabels = <String, String>{
  'PENDING': 'Pending',
  'CONFIRMED': 'Confirmed',
  'PROCESSING': 'Processing',
  'READY_FOR_SHIPMENT': 'Ready for shipment',
  'SHIPPED': 'Shipped',
  'DELIVERED': 'Delivered',
};

/// Delivery dashboard — the web app's `DeliveryDashboard` Overview, which pairs
/// the OTP confirmation explainer with the live delivery queue.
class DeliveryDashboardScreen extends ConsumerWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(deliverableOrdersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'DELIVERY',
          title: 'Delivery dashboard',
          subtitle:
              'Confirm deliveries with the buyer OTP and keep the delivery record accurate.',
        ),
        const InfoBox(
          'When you reach the buyer, ask for the six-digit OTP shown on their '
          'order. Entering the correct OTP marks the order as delivered and '
          'releases the protected settlement to the seller.',
        ),
        const SizedBox(height: 18),
        ordersAsync.when(
          data: (orders) => _Overview(orders: orders),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(deliverableOrdersProvider),
              ),
          loading: () => const LoadingState(),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.orders});
  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    final held = orders.fold<num>(0, (s, o) => s + (o.total ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Awaiting delivery',
              value: '${orders.length}',
              icon: 'box',
            ),
            MetricCard(
              label: 'Protected amount',
              value: money(held),
              icon: 'wallet',
            ),
          ],
        ),
        const SizedBox(height: 16),
        DataCard(
          title: 'Delivery operations',
          subtitle: '${orders.length} paid orders awaiting delivery',
          child:
              orders.isEmpty
                  ? const EmptyState(message: 'No deliveries pending')
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in orders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DeliveryTrackingCard(order: o, compact: true),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }
}

/// My Deliveries — the delivery partner's working queue, with the OTP
/// confirmation flow that releases the protected settlement.
class DeliveryDeliveriesScreen extends ConsumerWidget {
  const DeliveryDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(deliverableOrdersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'DELIVERY & SETTLEMENT',
          title: 'My Deliveries',
          subtitle:
              'Track delivery progress, the protected amount and the final delivery confirmation.',
        ),
        const InfoBox(
          'Paid orders are recorded as HELD by MVEC until the buyer\'s delivery '
          'OTP is verified. After successful verification, the protected amount '
          'is released to the seller.',
        ),
        const SizedBox(height: 18),
        ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return const DataCard(
                child: EmptyState(
                  message:
                      'No deliveries pending. Paid orders awaiting '
                      'delivery confirmation will appear here.',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DeliveryTrackingCard(order: o),
                  ),
              ],
            );
          },
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(deliverableOrdersProvider),
              ),
          loading: () => const LoadingState(),
        ),
      ],
    );
  }
}

/// One delivery record: order identity, the milestone ladder, the protected
/// amount and the OTP confirmation action.
///
/// The OTP field is the exact same call the web app makes —
/// `PATCH /orders/:id/deliver` — so confirming here marks the real order
/// delivered and releases the real settlement.
class DeliveryTrackingCard extends ConsumerStatefulWidget {
  const DeliveryTrackingCard({
    super.key,
    required this.order,
    this.compact = false,
  });

  final OrderRecord order;

  /// Compact mode trims the milestone ladder to a single status line, used on
  /// the dashboard where the queue is a summary rather than the work surface.
  final bool compact;

  @override
  ConsumerState<DeliveryTrackingCard> createState() =>
      _DeliveryTrackingCardState();
}

class _DeliveryTrackingCardState extends ConsumerState<DeliveryTrackingCard> {
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otp.text.trim();
    if (otp.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await ref.read(confirmDeliveryProvider)(widget.order.id!, otp);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = 'Delivery confirmed. Funds released.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = (order.status ?? 'PENDING').toUpperCase();
    final stepIndex =
        deliverySteps.contains(status) ? deliverySteps.indexOf(status) : 0;

    return DataCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.display,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.buyer ?? 'Buyer'} · ${order.vendor ?? 'Marketplace seller'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(order.total),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Funds held by MVEC',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MvColors.infoBoxText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.compact)
            _StatusLine(status: status, stepIndex: stepIndex)
          else
            _StepLadder(stepIndex: stepIndex),
          if (!widget.compact) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      isDense: true,
                      hintText: "Enter buyer's 6-digit OTP",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy || _otp.text.length != 6 ? null : _verify,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child:
                      _busy
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(_busy ? 'Verifying…' : 'Confirm delivery'),
                ),
              ],
            ),
            if (_success != null) ...[
              const SizedBox(height: 8),
              Text(
                _success!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MvColors.successText,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MvColors.errorText,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ask the buyer for the OTP shown on their order details page. The '
              'correct code confirms delivery and releases the held funds to the '
              'seller.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.stepIndex});
  final String status;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          MvIcon(
            stepIndex >= deliverySteps.length - 1 ? 'check' : 'box',
            size: 14,
            color: MvColors.primaryDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              deliveryStepLabels[status] ?? status,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Step ${stepIndex + 1} of ${deliverySteps.length}',
            style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLadder extends StatelessWidget {
  const _StepLadder({required this.stepIndex});
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < deliverySteps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color:
                        i <= stepIndex
                            ? MvColors.primaryDeep
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    i < stepIndex ? Icons.check : Icons.circle,
                    size: i < stepIndex ? 12 : 5,
                    color: i <= stepIndex ? Colors.white : MvColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  deliveryStepLabels[deliverySteps[i]] ?? deliverySteps[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        i == stepIndex ? FontWeight.w800 : FontWeight.w500,
                    color:
                        i <= stepIndex
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
