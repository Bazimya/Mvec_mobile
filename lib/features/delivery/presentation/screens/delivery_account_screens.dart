import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../models/catalog.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/mv_icon.dart';
import '../providers/delivery_providers.dart';

/// Delivery earnings — the delivery partner's view of the money their
/// completed deliveries represent.
///
/// The web app routes `/delivery/earnings` into the same `DeliveryTracking`
/// surface, so this screen keeps that connection: the amounts shown are the
/// real order totals of deliveries the API reports as delivered, and the list
/// links straight back to the delivery records that produced them.
class DeliveryEarningsScreen extends ConsumerWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(deliveryHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'DELIVERY & SETTLEMENT',
          title: 'Earnings',
          subtitle:
              'Delivery earnings follow the orders you confirmed. Each completed '
              'delivery releases the protected settlement to the seller.',
        ),
        historyAsync.when(
          data: (orders) {
            final total = orders.fold<num>(0, (s, o) => s + (o.total ?? 0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricCard(
                      label: 'Completed deliveries',
                      value: '${orders.length}',
                      icon: 'box',
                    ),
                    MetricCard(
                      label: 'Order value delivered',
                      value: money(total),
                      icon: 'wallet',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DataCard(
                  title: 'Earnings ledger',
                  subtitle: '${orders.length} settled deliveries',
                  child:
                      orders.isEmpty
                          ? const EmptyState(
                            message:
                                'No completed deliveries yet. Earnings appear '
                                'here once a delivery is confirmed.',
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final o in orders) _EarningRow(order: o),
                            ],
                          ),
                ),
              ],
            );
          },
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(deliveryHistoryProvider),
              ),
          loading: () => const LoadingState(),
        ),
      ],
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.order});
  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final settled = (order.paymentStatus ?? '').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MvColors.metricIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 17, color: MvColors.primaryDeep),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.display,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.buyer ?? 'Buyer'} · ${shortDateTime(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(order.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                settled.isEmpty ? 'SETTLED' : settled,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: MvColors.successText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Delivery history — every delivery record this account has completed.
class DeliveryHistoryScreen extends ConsumerWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(deliveryHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'DELIVERY',
          title: 'History',
          subtitle: 'Completed deliveries and their settlement outcome.',
        ),
        historyAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return const DataCard(
                child: EmptyState(
                  message:
                      'No delivery history yet. Completed deliveries will '
                      'be listed here.',
                ),
              );
            }
            return DataCard(
              title: 'Delivery history',
              subtitle: '${orders.length} completed deliveries',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final o in orders) _EarningRow(order: o)],
              ),
            );
          },
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(deliveryHistoryProvider),
              ),
          loading: () => const LoadingState(),
        ),
      ],
    );
  }
}

/// Delivery settings — the delivery partner's own profile, identity and
/// preferences. Shares the account screen the web app shows for `/profile`.
class DeliverySettingsScreen extends ConsumerWidget {
  const DeliverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'DELIVERY',
          title: 'Settings',
          subtitle: 'Your delivery partner profile and app preferences.',
        ),
        DataCard(
          title: 'Delivery partner profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: MvColors.gradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials(user?.display ?? 'D'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.display ?? 'Delivery partner',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? user?.phone ?? 'Not set',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              KeyValueGrid(
                entries: [
                  MapEntry('Account type', 'Delivery partner'),
                  MapEntry('Status', (user?.status ?? 'ACTIVE').toUpperCase()),
                  MapEntry('User ID', user?.id ?? '—'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DataCard(
          title: 'Preferences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Dark mode',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Match the MVEC interface to your device theme.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                value: isDark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
              const Divider(height: 20),
              _LinkRow(
                icon: 'users',
                label: 'Messages',
                detail: 'Talk to MVEC, vendors and buyers',
                onTap: () => context.push('/delivery/messages'),
              ),
              _LinkRow(
                icon: 'home',
                label: 'View marketplace',
                detail: 'Browse MVEC as a customer',
                onTap: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MvIcon(icon, size: 20, color: MvColors.primaryDeep),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        detail,
        style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
