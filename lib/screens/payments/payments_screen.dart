import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/catalog.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/smart_table.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'ADMIN · PAYMENTS',
          title: 'Payments',
          subtitle:
              'Monitor payment confirmations and protected settlement states.',
        ),
        ordersAsync.when(
          data: (orders) {
            final held = _settlementTotal(orders, const {'HELD', 'ON_HOLD'});
            final released = _settlementTotal(orders, const {
              'RELEASED',
              'COMPLETED',
              'PAID',
            });
            final hasSettlementData = orders.any(_settlementStatusIsPresent);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataCard(
                  title: 'Settlement summary',
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Held funds',
                          value: hasSettlementData ? money(held) : '—',
                          icon: 'wallet',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          label: 'Released',
                          value: hasSettlementData ? money(released) : '—',
                          icon: 'check',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasSettlementData)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: InfoBox(
                      'Settlement totals are unavailable because the order API response contains no settlement status.',
                    ),
                  ),
                const SizedBox(height: 16),
                SmartTable(
                  columns: const [
                    MvColumn('Id', 'Id', bold: true),
                    MvColumn('Order', 'Order'),
                    MvColumn('Payer', 'Payer'),
                    MvColumn('Amount', 'Amount'),
                    MvColumn('Method', 'Method'),
                    MvColumn('Status', 'Status'),
                  ],
                  rows: [
                    for (final o in orders)
                      {
                        'Id': _paymentId(o),
                        'Order': o.display,
                        'Payer': o.buyer ?? '—',
                        'Amount': money(o.total),
                        'Method': _methodLabel(o.paymentMethod),
                        'Status': o.paymentStatus ?? '—',
                      },
                  ],
                  pageSize: 8,
                  filterKey: 'Status',
                  filterLabel: 'Status',
                  filterOptions: const [],
                ),
              ],
            );
          },
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(ordersProvider),
              ),
          loading: () => const LoadingState(),
        ),
      ],
    );
  }

  num _settlementTotal(List<OrderRecord> orders, Set<String> statuses) {
    return orders.fold<num>(0, (total, order) {
      final amount = order.total ?? 0;
      return statuses.contains(_settlementStatus(order))
          ? total + amount
          : total;
    });
  }

  bool _settlementStatusIsPresent(OrderRecord order) =>
      _settlementStatus(order).isNotEmpty;

  String _settlementStatus(OrderRecord order) {
    final raw = order.raw;
    if (raw == null) return '';
    final settlement = raw['settlement'];
    final payment = raw['payment'];
    final value =
        settlement is Map
            ? settlement['status']
            : raw['settlementStatus'] ??
                (payment is Map ? payment['settlementStatus'] : null);
    return value?.toString().toUpperCase() ?? '';
  }

  String _paymentId(OrderRecord o) {
    final p = o.raw?['payment'];
    if (p is Map) {
      final id = p['id'] ?? p['transactionId'] ?? p['reference'] ?? p['_id'];
      if (id != null) return id.toString();
    }
    return o.id ?? '—';
  }

  String _methodLabel(String? m) {
    final s = (m ?? '').toUpperCase();
    if (s.contains('MTN') || s.contains('MOMO') || s.contains('MOBILE')) {
      return 'MTN MoMo';
    }
    if (s.contains('AIRTEL')) {
      return 'Airtel Money';
    }
    return (m == null || m.isEmpty) ? 'Card' : m;
  }
}
