import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider('30d'));
    final revenueAsync = ref.watch(reportRevenueProvider('30d'));

    final s = summaryAsync.when(
      data: (v) => v,
      error: (_, __) => null,
      loading: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHead(
          eyebrow: 'SUPER ADMIN · ANALYTICS',
          title: 'Marketplace analytics',
        ),
        _metricGrid([
          MetricCard(
            label: 'GMV',
            value: s == null ? '—' : money(s.grossSales),
            icon: 'wallet',
          ),
          MetricCard(
            label: 'Orders',
            value: s == null ? '—' : numFmt(s.orders),
            icon: 'cart',
          ),
          MetricCard(
            label: 'Completed',
            value: s == null ? '—' : money(s.paymentVolume),
            icon: 'check',
          ),
          MetricCard(
            label: 'Refund rate',
            value:
                s == null
                    ? '—'
                    : '${_pct(s.refunds, s.grossSales).toStringAsFixed(1)}%',
            delta: s == null ? null : '% of sales',
            icon: 'bell',
          ),
          MetricCard(
            label: 'Active users',
            value: s == null ? '—' : numFmt(s.customers),
            icon: 'users',
          ),
          MetricCard(
            label: 'Average order',
            value: s == null ? '—' : money(_avg(s.grossSales, s.orders)),
            icon: 'chart',
          ),
        ]),
        const SizedBox(height: 16),
        DataCard(
          title: 'Revenue trend',
          child: revenueAsync.when(
            loading: () => const LoadingState(),
            error:
                (error, _) => ErrorState(
                  message: friendlyError(error),
                  onRetry: () => ref.invalidate(reportRevenueProvider('30d')),
                ),
            data:
                (series) =>
                    FakeBarChart(values: series.series, labels: series.labels),
          ),
        ),
      ],
    );
  }

  Widget _metricGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100 ? 3 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (i > 0) rows.add(const SizedBox(height: 14));
          rows.add(
            Row(
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: 14),
                  Expanded(
                    child:
                        i + j < children.length
                            ? children[i + j]
                            : const SizedBox(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

double _pct(num? part, num? total) {
  final t = total ?? 0;
  if (t == 0) return 0;
  return ((part ?? 0) / t) * 100;
}

num _avg(num? total, num? count) {
  final c = count ?? 0;
  if (c == 0) return 0;
  return (total ?? 0) / c;
}
