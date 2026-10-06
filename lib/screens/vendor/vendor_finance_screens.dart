import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/catalog.dart';
import '../../../models/vendor.dart';
import '../../../models/vendor_product.dart';
import '../../../providers/vendor_providers.dart';
import '../../../widgets/common.dart';

/// Vendor payouts — a port of the web console's vendor payout page, driven by
/// the same three routes it uses: `GET /payouts/balance`,
/// `GET /payouts/history` and `POST /payouts/request`.
///
/// The available balance is the platform's own record of what MVEC holds for
/// this vendor, so nothing here is derived or estimated.
class VendorPayoutsScreen extends ConsumerStatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  ConsumerState<VendorPayoutsScreen> createState() =>
      _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends ConsumerState<VendorPayoutsScreen> {
  final _amount = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _submit(VendorPayoutBalance balance) async {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) return;
    if (_accountName.text.trim().isEmpty ||
        _accountNumber.text.trim().isEmpty) {
      return;
    }
    final ok = await ref
        .read(vendorPayoutRequestProvider.notifier)
        .submit(
          amount: amount,
          accountName: _accountName.text.trim(),
          accountNumber: _accountNumber.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      _amount.clear();
      _accountName.clear();
      _accountNumber.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(vendorPayoutBalanceProvider);
    final historyAsync = ref.watch(vendorPayoutHistoryProvider);
    final request = ref.watch(vendorPayoutRequestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Payouts',
          subtitle:
              'Your available balance, and the account MVEC should pay out to.',
        ),
        balanceAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorPayoutBalanceProvider),
              ),
          data:
              (balance) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      MetricCard(
                        label: 'Available',
                        value: money(balance.availableBalance),
                        icon: 'wallet',
                        delta: 'Ready to withdraw',
                      ),
                      MetricCard(
                        label: 'Pending',
                        value: money(balance.pendingBalance),
                        icon: 'wallet',
                        delta: 'Held until delivery',
                      ),
                      MetricCard(
                        label: 'Total earned',
                        value: money(balance.totalEarned),
                        icon: 'chart',
                        delta: 'All-time',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DataCard(
                    title: 'Request payout',
                    subtitle:
                        'Minimum withdrawal ${money(balance.minimumPayout)}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (request.message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              request.message!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: MvColors.successText,
                              ),
                            ),
                          ),
                        if (request.error != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              request.error!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: MvColors.errorText,
                              ),
                            ),
                          ),
                        ],
                        TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount (${balance.currency})',
                            helperText:
                                'Available ${money(balance.availableBalance)}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _accountName,
                          decoration: const InputDecoration(
                            labelText: 'Account name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _accountNumber,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile money number',
                            hintText: '+250 7xx xxx xxx',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GradientButton(
                            label:
                                request.busy ? 'Requesting…' : 'Request payout',
                            icon: 'wallet',
                            onPressed:
                                request.busy ||
                                        balance.availableBalance <
                                            balance.minimumPayout
                                    ? null
                                    : () => _submit(balance),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  historyAsync.when(
                    loading: () => const LoadingState(),
                    error:
                        (e, _) => ErrorState(
                          message: friendlyError(e),
                          onRetry:
                              () => ref.invalidate(vendorPayoutHistoryProvider),
                        ),
                    data:
                        (payouts) => DataCard(
                          title: 'Payout history',
                          subtitle: '${payouts.length} requests',
                          child:
                              payouts.isEmpty
                                  ? const EmptyState(
                                    message:
                                        'No payout requests yet. Submit one to '
                                        'receive your balance.',
                                  )
                                  : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final p in payouts)
                                        _PayoutRow(payout: p),
                                    ],
                                  ),
                        ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});
  final PayoutRecord payout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(payout.amount),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    payout.reference,
                    if (payout.createdAt != null)
                      shortDateTime(payout.createdAt),
                  ].whereType<String>().join(' · '),
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
          StatusChip((payout.status ?? 'PENDING').toUpperCase()),
        ],
      ),
    );
  }
}

/// Vendor transactions — the payout ledger, i.e. exactly the
/// `GET /payouts/history` records the web console lists on this page.
class VendorTransactionsScreen extends ConsumerWidget {
  const VendorTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(vendorPayoutHistoryProvider);
    final balanceAsync = ref.watch(vendorPayoutBalanceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Transactions',
          subtitle:
              'Every payout MVEC has released or is holding for your store.',
        ),
        balanceAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data:
              (b) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricCard(
                    label: 'Available',
                    value: money(b.availableBalance),
                    icon: 'wallet',
                  ),
                  MetricCard(
                    label: 'Pending',
                    value: money(b.pendingBalance),
                    icon: 'wallet',
                  ),
                  MetricCard(
                    label: 'Withdrawn',
                    value: money(b.totalWithdrawn),
                    icon: 'check',
                  ),
                ],
              ),
        ),
        const SizedBox(height: 16),
        historyAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorPayoutHistoryProvider),
              ),
          data:
              (payouts) => DataCard(
                title: 'Transaction ledger',
                subtitle: '${payouts.length} entries',
                child:
                    payouts.isEmpty
                        ? const EmptyState(
                          message: 'No transactions recorded yet.',
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final p in payouts) _PayoutRow(payout: p),
                          ],
                        ),
              ),
        ),
      ],
    );
  }
}

/// Vendor analytics — a port of the web console's vendor analytics page, built
/// from the vendor's own store overview and catalogue rather than a
/// vendor-specific reporting endpoint.
class VendorAnalyticsScreen extends ConsumerWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(vendorStatsProvider);
    final productsAsync = ref.watch(
      vendorProductsProvider(const VendorProductQuery()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Analytics',
          subtitle:
              'How your store is performing, measured from your own catalogue and orders.',
        ),
        statsAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorStatsProvider),
              ),
          data:
              (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      MetricCard(
                        label: 'Sales today',
                        value: money(s.dailySales),
                        icon: 'chart',
                        delta:
                            s.salesDelta == null
                                ? null
                                : '${s.salesDelta! > 0 ? '+' : ''}${s.salesDelta}%',
                      ),
                      MetricCard(
                        label: 'Active orders',
                        value: '${s.activeOrders ?? 0}',
                        icon: 'cart',
                      ),
                      MetricCard(
                        label: 'Total orders',
                        value: '${s.totalOrders ?? 0}',
                        icon: 'box',
                      ),
                      MetricCard(
                        label: 'Total products',
                        value: '${s.totalProducts ?? 0}',
                        icon: 'tag',
                      ),
                      MetricCard(
                        label: 'Low stock',
                        value: '${s.lowStock ?? 0}',
                        icon: 'bell',
                      ),
                      MetricCard(
                        label: 'Store rating',
                        value:
                            s.rating == null
                                ? '—'
                                : '${s.rating!.toStringAsFixed(1)} / 5',
                        icon: 'heart',
                        delta:
                            s.ratingCount == null
                                ? null
                                : '${s.ratingCount} reviews',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  productsAsync.when(
                    loading: () => const LoadingState(),
                    error:
                        (e, _) => ErrorState(
                          message: friendlyError(e),
                          onRetry: () => ref.invalidate(vendorProductsProvider),
                        ),
                    data:
                        (page) => _TopProducts(
                          products: page.items,
                          total: page.total ?? page.items.length,
                        ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.products, required this.total});
  final List<VendorProduct> products;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const DataCard(
        child: EmptyState(
          message: 'No products yet. Analytics appear once you list products.',
        ),
      );
    }
    final ranked = [...products]
      ..sort((a, b) => (b.sold ?? 0).compareTo(a.sold ?? 0));
    return DataCard(
      title: 'Best sellers',
      subtitle: 'By units sold · $total products in your catalogue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in ranked.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name ?? 'Product',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${p.sold ?? 0} sold',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    money(p.price),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Vendor purchases — the vendor's own wholesale purchase records from
/// `GET /wholesale/orders/mine`.
class VendorPurchasesScreen extends ConsumerWidget {
  const VendorPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(vendorWholesalePurchasesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Purchases',
          subtitle: 'Wholesale orders you have placed with MVEC suppliers.',
        ),
        purchasesAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorWholesalePurchasesProvider),
              ),
          data:
              (orders) => DataCard(
                title: 'Purchase orders',
                subtitle: '${orders.length} wholesale orders',
                child:
                    orders.isEmpty
                        ? const EmptyState(
                          message:
                              'No wholesale purchases yet. Orders you place '
                              'with suppliers appear here.',
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final o in orders) _WholesaleRow(order: o),
                          ],
                        ),
              ),
        ),
      ],
    );
  }
}

class _WholesaleRow extends StatelessWidget {
  const _WholesaleRow({required this.order});
  final WholesaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.display,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (order.supplier != null) order.supplier!,
                    if (order.items > 0) '${order.items} items',
                    if (order.createdAt != null) shortDateTime(order.createdAt),
                  ].join(' · '),
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
          const SizedBox(width: 10),
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
              const SizedBox(height: 4),
              StatusChip((order.status ?? 'PENDING').toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vendor reviews — assembled from the vendor's own products, because the API
/// only serves reviews per product (`GET /reviews/product/:id`).
class VendorReviewsScreen extends ConsumerWidget {
  const VendorReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
      vendorProductsProvider(const VendorProductQuery()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Reviews',
          subtitle: 'What buyers said about the products in your store.',
        ),
        productsAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorProductsProvider),
              ),
          data:
              (page) =>
                  page.items.isEmpty
                      ? const DataCard(
                        child: EmptyState(
                          message:
                              'No products yet, so there are no reviews to show.',
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final p in page.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ProductReviews(product: p),
                            ),
                        ],
                      ),
        ),
      ],
    );
  }
}

class _ProductReviews extends ConsumerWidget {
  const _ProductReviews({required this.product});
  final VendorProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = product.id;
    if (id == null) {
      return DataCard(
        title: product.name,
        child: const EmptyState(message: 'No reviews'),
      );
    }
    final reviewsAsync = ref.watch(vendorProductReviewsProvider(id));
    return DataCard(
      title: product.name,
      subtitle: product.rating == null ? null : '${product.rating} / 5',
      child: reviewsAsync.when(
        loading: () => const LoadingState(),
        error:
            (e, _) => ErrorState(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(vendorProductReviewsProvider(id)),
            ),
        data:
            (reviews) =>
                reviews.isEmpty
                    ? const EmptyState(
                      message: 'No reviews for this product yet',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final r in reviews)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReviewRow(review: r),
                          ),
                      ],
                    ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});
  final ReviewRecord review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.author ?? 'Buyer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (review.rating != null)
              Text(
                '${review.rating}/5',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: MvColors.primaryDeep,
                ),
              ),
            if (review.createdAt != null) ...[
              const SizedBox(width: 10),
              Text(
                shortDateTime(review.createdAt),
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          review.comment ?? '',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Theme.of(context).hintColor,
          ),
        ),
      ],
    );
  }
}

/// Vendor categories — the read-only category list the vendor's products are
/// filed under, served by the same `GET /categories` route the product form
/// uses.
class VendorCategoriesScreen extends ConsumerWidget {
  const VendorCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(vendorCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHead(
          eyebrow: 'SELLER PLATFORM',
          title: 'Categories',
          subtitle: 'The marketplace categories you can list products under.',
        ),
        categoriesAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(vendorCategoriesProvider),
              ),
          data:
              (categories) => DataCard(
                title: 'Product categories',
                subtitle: '${categories.length} categories',
                child:
                    categories.isEmpty
                        ? const EmptyState(message: 'No categories available')
                        : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in categories)
                              Chip(
                                label: Text(c.name ?? ''),
                                avatar: const Icon(Icons.tag, size: 14),
                              ),
                          ],
                        ),
              ),
        ),
      ],
    );
  }
}
