import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/mv_icon.dart';
import '../../data/models/affiliate_earnings.dart';
import '../providers/affiliate_providers.dart';
import '../widgets/affiliate_widgets.dart';

/// Affiliate wallet — a direct port of the web console's Wallet page, backed
/// by `GET /affiliates/wallet`.
///
/// Shows the real balance split the API returns and surfaces the platform
/// minimum withdrawal, so a partner can see at a glance whether they can
/// withdraw and jump straight to the request form.
class AffiliateWalletScreen extends ConsumerWidget {
  const AffiliateWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(affiliateWalletProvider);
    final payoutsAsync = ref.watch(affiliatePayoutsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHead(
          eyebrow: 'Earnings',
          title: 'Wallet',
          subtitle:
              'Your commission balance, what is still pending and what you have already withdrawn.',
          actions: [
            GradientButton(
              label: 'Withdraw',
              icon: 'wallet',
              onPressed: () => context.go('/affiliate/withdrawals'),
            ),
          ],
        ),
        walletAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(affiliateWalletProvider),
              ),
          data: (w) => _WalletBody(wallet: w, payoutsAsync: payoutsAsync),
        ),
      ],
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.wallet, required this.payoutsAsync});

  final AffiliateWallet wallet;
  final AsyncValue<List<AffiliatePayout>> payoutsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWithdraw = wallet.availableBalance >= wallet.minimumPayout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Available balance',
              value: money(wallet.availableBalance),
              icon: 'wallet',
            ),
            MetricCard(
              label: 'Pending commission',
              value: money(wallet.pendingBalance),
              icon: 'chart',
            ),
            MetricCard(
              label: 'Total earned',
              value: money(wallet.totalEarned),
              icon: 'tag',
            ),
            MetricCard(
              label: 'Total withdrawn',
              value: money(wallet.totalWithdrawn),
              icon: 'check',
            ),
          ],
        ),
        const SizedBox(height: 16),
        DataCard(
          title: 'Withdrawal eligibility',
          subtitle: 'Minimum withdrawal ${money(wallet.minimumPayout)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MvIcon(
                    canWithdraw ? 'check' : 'bell',
                    size: 16,
                    color:
                        canWithdraw
                            ? MvColors.successText
                            : MvColors.warningText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      canWithdraw
                          ? 'Your available balance meets the minimum withdrawal.'
                          : 'You need ${money(wallet.minimumPayout - wallet.availableBalance)} '
                              'more in available commission to withdraw.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (wallet.lastPayoutAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Last withdrawal ${shortDateTime(wallet.lastPayoutAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: GradientButton(
                  label: 'Request withdrawal',
                  icon: 'plus',
                  onPressed:
                      canWithdraw
                          ? () => context.go('/affiliate/withdrawals')
                          : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        payoutsAsync.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(affiliatePayoutsProvider),
              ),
          data:
              (payouts) => DataCard(
                title: 'Recent withdrawals',
                subtitle: '${payouts.length} payout requests',
                child:
                    payouts.isEmpty
                        ? const EmptyState(
                          message: 'No withdrawal requests yet.',
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final p in payouts.take(5))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PayoutRow(payout: p),
                              ),
                          ],
                        ),
              ),
        ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});
  final AffiliatePayout payout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 34,
          height: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MvColors.metricIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wallet, size: 16, color: MvColors.primaryDeep),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                money(payout.amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shortDateTime(payout.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
        InfoPill('Status', (payout.status ?? 'PENDING').toUpperCase()),
      ],
    );
  }
}
