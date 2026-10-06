import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api_client.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/app_theme.dart';
import '../../data/services/api_order_service.dart';

/// Orders tab: current (active) and past orders.
///
/// Backed by `GET /orders/my-orders`, the same endpoint the web account page
/// reads. There is no local fallback list - a failed request shows the error
/// with a retry rather than placeholder orders the shopper never placed.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.service});

  /// Overridable so widget tests can drive the list without a network. Defaults
  /// to the live `/orders/my-orders` service.
  final ApiOrderService? service;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  ApiOrderService? _service;
  List<BuyerOrder> _orders = const <BuyerOrder>[];
  bool _isLoading = true;
  String? _error;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Orders are scoped to the signed-in shopper, so the list loads on mount.
    _service ??= widget.service ?? ref.read(buyerOrderServiceProvider);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final orders = await _service!.myOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancel(BuyerOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order ${order.orderNumber} will be cancelled and any held payment '
          'refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updated = await _service!.cancel(order.id);
      if (!mounted) return;
      setState(() {
        _orders = _orders
            .map((existing) => existing.id == order.id ? updated : existing)
            .toList();
        _message = 'Order ${order.orderNumber} cancelled.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Orders', style: AppTextStyles.headline(context)),
          ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'Active (${_count(onlyActive: true)})'),
              Tab(text: 'Past (${_count(onlyActive: false)})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OrdersList(
                  orders: _orders.where((o) => o.status.isActive).toList(),
                  isLoading: _isLoading,
                  error: _error,
                  message: _message,
                  onRetry: _load,
                  onCancel: _cancel,
                  canCancel: _service!.canCancel,
                  emptyLabel: 'No active orders',
                  emptyHint: 'Orders you place will show up here.',
                ),
                _OrdersList(
                  orders: _orders.where((o) => !o.status.isActive).toList(),
                  isLoading: _isLoading,
                  error: _error,
                  message: _message,
                  onRetry: _load,
                  onCancel: _cancel,
                  canCancel: _service!.canCancel,
                  emptyLabel: 'No past orders yet',
                  emptyHint: 'Delivered and cancelled orders appear here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _count({required bool onlyActive}) => _orders
      .where((order) => order.status.isActive == onlyActive)
      .length;
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.isLoading,
    required this.error,
    required this.message,
    required this.onRetry,
    required this.onCancel,
    required this.canCancel,
    required this.emptyLabel,
    required this.emptyHint,
  });

  final List<BuyerOrder> orders;
  final bool isLoading;
  final String? error;
  final String? message;
  final Future<void> Function() onRetry;
  final Future<void> Function(BuyerOrder order) onCancel;
  final bool Function(BuyerOrder order) canCancel;
  final String emptyLabel;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && orders.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your orders',
        message: error!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }

    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: emptyLabel,
        message: emptyHint,
      );
    }

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length + (message != null || error != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0 && (message != null || error != null)) {
            return _Banner(
              text: message ?? error!,
              isError: message == null,
            );
          }
          final order = orders[index - (message != null || error != null ? 1 : 0)];
          return _OrderCard(
            order: order,
            onCancel: canCancel(order) ? () => onCancel(order) : null,
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onCancel});

  final BuyerOrder order;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      BuyerOrderStatus.delivered => AppColors.success,
      BuyerOrderStatus.cancelled => AppColors.error,
      BuyerOrderStatus.shipped || BuyerOrderStatus.outForDelivery =>
        AppColors.primary,
      _ => AppColors.warning,
    };

    final summary = order.itemNames.isEmpty
        ? '${order.itemCount} item(s)'
        : order.itemNames.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderNumber,
                  style: AppTextStyles.title(context).copyWith(fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary(context).copyWith(fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.dateLabel.isNotEmpty) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    color: context.mv.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(order.dateLabel, style: AppTextStyles.caption(context)),
                ],
                const Spacer(),
                Text(
                  '${order.total.toStringAsFixed(2)} RWF',
                  style: AppTextStyles.price(context).copyWith(fontSize: 14),
                ),
              ],
            ),
            if (order.paymentStatus.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Payment: ${order.paymentStatus}',
                style: AppTextStyles.caption(context),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.mv.textMuted, size: 56),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.title(context)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onAction?.call(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}