import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/marketplace/presentation/Screens/main_navigation.dart';
import '../features/affiliate/presentation/screens/affiliate_dashboard_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_profile_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_settings_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_products_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_campaigns_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_links_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_stats_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_earnings_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_payouts_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_notifications_screen.dart';
import '../features/affiliate/presentation/screens/affiliate_wallet_screen.dart';
import '../features/affiliate/presentation/shell/affiliate_shell.dart';
import '../features/delivery/presentation/screens/delivery_account_screens.dart';
import '../features/delivery/presentation/screens/delivery_screens.dart';
import '../features/delivery/presentation/shell/delivery_shell.dart';
import '../providers/auth_provider.dart';
import '../widgets/feature_unavailable_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/account/account_screen.dart';
import '../screens/buyers/buyers_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/verification_code_screen.dart';
import '../screens/layout/admin_shell.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/audit_logs/audit_logs_screen.dart';
import '../screens/categories/categories_screen.dart';
import '../screens/commission_rules/commission_rules_screen.dart';
import '../screens/disputes/disputes_screen.dart';
import '../screens/deliveries/deliveries_screen.dart';
import '../screens/advertising/advertising_screen.dart';
import '../screens/affiliates/affiliates_screen.dart';
import '../screens/languages/languages_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/locations/locations_screen.dart';
import '../screens/matching/matching_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/overview/overview_screen.dart';
import '../screens/payments/payments_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/recommendations/recommendations_screen.dart';
import '../screens/refunds/refunds_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reviews/reviews_screen.dart';
import '../screens/risk/risk_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/security/security_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/subscriptions/subscriptions_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';
import '../screens/suppliers/supplier_inventory_screen.dart';
import '../screens/suppliers/supplier_notifications_screen.dart';
import '../screens/suppliers/supplier_orders_screen.dart';
import '../screens/suppliers/supplier_overview_screen.dart';
import '../screens/suppliers/supplier_products_screen.dart';
import '../screens/suppliers/supplier_profile_screen.dart';
import '../screens/suppliers/supplier_shell.dart';
import '../screens/system/system_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../screens/trust/trust_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/vendors/vendors_screen.dart';
import '../screens/commissions/commissions_screen.dart';
import '../screens/acquisitions/acquisitions_screen.dart';
import '../screens/vendor/vendor_shell.dart';
import '../screens/vendor/vendor_overview_screen.dart';
import '../screens/vendor/vendor_products_screen.dart';
import '../screens/vendor/become_seller_screen.dart';
import '../screens/vendor/vendor_finance_screens.dart';
import '../screens/vendor/vendor_profile_screen.dart';
import '../features/vendor/screens/vendor_orders_screen.dart';
import '../features/vendor/screens/vendor_sales_screen.dart';
import '../features/vendor/screens/vendor_notifications_screen.dart';
import '../features/vendor/screens/vendor_settings_screen.dart';

/// A supplier portal destination the API does not serve yet.
class _UnavailablePage {
  const _UnavailablePage(this.path, this.title, this.icon, this.detail);

  final String path;
  final String title;
  final String icon;
  final String detail;
}

/// The remaining entries of the frontend supplier nav groups. The web app
/// fills these with hard-coded seed rows, so the mobile app routes them to a
/// clear "not connected yet" state rather than inventing payouts, staff
/// records or delivery milestones.
const _unavailableSupplierPages = <_UnavailablePage>[
  _UnavailablePage(
    '/supplier/supply-requests',
    'Supply requests',
    'cart',
    'Inbound supply requests are not exposed for supplier accounts yet. The '
        'API only serves your wholesale catalogue, profile and orders.',
  ),
  _UnavailablePage(
    '/supplier/delivery',
    'Delivery & settlement',
    'box',
    'Delivery milestones and settlement releases are not served to suppliers '
        'yet. The order list tracks the supply status that the API returns.',
  ),
  _UnavailablePage(
    '/supplier/payments',
    'Payments',
    'wallet',
    'Supplier payouts are not exposed by the MVEC API for supplier accounts '
        'yet, so no amounts are shown here.',
  ),
  _UnavailablePage(
    '/supplier/transactions',
    'Transactions',
    'wallet',
    'A supplier-scoped transaction ledger is not available yet.',
  ),
  _UnavailablePage(
    '/supplier/analytics',
    'Analytics',
    'chart',
    'Trend reporting is not served for suppliers yet. Your catalogue and order '
        'totals are available on the dashboard.',
  ),
  _UnavailablePage(
    '/supplier/reports',
    'Reports',
    'chart',
    'Scheduled and historical supplier reports are not available yet.',
  ),
  _UnavailablePage(
    '/supplier/reviews',
    'Reviews',
    'heart',
    'Buyer reviews for your business are not served by the API yet.',
  ),
  _UnavailablePage(
    '/supplier/team',
    'Team & staff',
    'users',
    'Supplier staff accounts are not managed through the API yet.',
  ),
];

/// The vendor portal destinations the web console fills with fabricated rows.
///
/// `ModulePage` in the web `src/pages/VendorDashboard.jsx` stores these pages in
/// `localStorage` seeded with hard-coded arrays — no API call is ever made. The
/// mobile app refuses to reproduce those numbers as if they were real, so each
/// of these routes keeps its place in the navigation and states that the data
/// is not connected yet.
const _unavailableVendorPages = <_UnavailablePage>[
  _UnavailablePage(
    '/vendor/stores',
    'My Store',
    'shop',
    'The web console seeds multiple store records in the browser. The MVEC '
        'API serves one store per vendor account at /stores/mine, which is '
        'what the Store Profile page uses.',
  ),
  _UnavailablePage(
    '/vendor/customers',
    'Customers',
    'users',
    'Customer records are seeded in the browser by the web console. The API '
        'does not expose a vendor-scoped customer list yet.',
  ),
  _UnavailablePage(
    '/vendor/suppliers',
    'Find Suppliers',
    'shop',
    'Supplier discovery is a static browser-side list in the web console. No '
        'supplier search endpoint is exposed to vendor accounts yet.',
  ),
  _UnavailablePage(
    '/vendor/affiliates',
    'Affiliate Marketing',
    'users',
    'The affiliate programme dashboard is rendered from hard-coded metrics in '
        'the web console, not from an API.',
  ),
  _UnavailablePage(
    '/vendor/advertisements',
    'Advertisements',
    'tag',
    'Vendor advertising configuration has no vendor-scoped endpoint. Campaign '
        'management is served to the MVEC admin only.',
  ),
  _UnavailablePage(
    '/vendor/promotions',
    'Promotions',
    'tag',
    'Promotions and coupons are stored in the browser by the web console. No '
        'vendor promotion endpoint is exposed yet.',
  ),
  _UnavailablePage(
    '/vendor/subscription',
    'Subscription',
    'wallet',
    'Vendor plans are static module defaults in the web console. Subscription '
        'records the API serves are admin-scoped.',
  ),
  _UnavailablePage(
    '/vendor/refunds',
    'Refunds',
    'wallet',
    'Refund requests are seeded rows in the web console. Refunds reach a '
        'vendor through dispute arbitration, which is served from the Orders '
        'and Disputes records.',
  ),
  _UnavailablePage(
    '/vendor/shipping',
    'Shipping',
    'shop',
    'Shipping zones are hard-coded per browser in the web console. The '
        '/shipping/zones data the API serves is platform-wide, not vendor '
        'configurable.',
  ),
  _UnavailablePage(
    '/vendor/delivery',
    'Delivery & Settlement',
    'box',
    'The web console renders this page from mock delivery data. Delivery '
        'tracking and settlement live on each order, and the delivery partner '
        'confirms them with the buyer OTP from the delivery portal.',
  ),
  _UnavailablePage(
    '/vendor/reports',
    'Reports',
    'chart',
    'Vendor reports are generated in the browser from seeded rows. The report '
        'endpoints the API serves are admin-scoped.',
  ),
  _UnavailablePage(
    '/vendor/team',
    'Team / Staff',
    'users',
    'Staff accounts are seeded in the browser by the web console. Staff records '
        'are not managed through the API for vendor accounts.',
  ),
];

/// Routes that a signed-in user must never stay on.
const _publicAuthPaths = <String>[
  '/login',
  '/signup',
  '/forgot-password',
  '/verify-code',
  '/reset-password',
];

// Marketplace routes a signed-out visitor may browse without an account.
// Anything that touches an account, an order or money is deliberately absent
// here and is guarded below instead.
const _publicRoutes = <String>[
  '/home',
  '/shop',
  '/search',
  '/categories',
  '/vendors',
  '/product',
];

bool _isPublicRoute(String location) {
  if (_publicAuthPaths.any(location.startsWith)) return true;
  if (_publicRoutes.any(location.startsWith)) return true;
  return false;
}

final routerProvider = Provider<GoRouter>((ref) {
  final gate = ValueNotifier(0);
  ref.onDispose(gate.dispose);
  ref.listen(authControllerProvider, (prev, next) {
    if (prev?.isLoggedIn != next.isLoggedIn ||
        prev?.restoring != next.restoring) {
      gate.value++;
    }
  });

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: gate,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final isPublic = _isPublicRoute(loc);
      if (auth.restoring) return null;

      if (auth.isLoggedIn) {
        final user = auth.session!.user;
        // A signed-in user should never sit on a public auth page.
        if (_publicAuthPaths.any(loc.startsWith)) {
          return roleHome(user);
        }
        // Only super admins may enter the control center.
        if (loc.startsWith('/admin') && user.userType != 'super_admin') {
          return '/home';
        }
        // Only affiliates may enter the affiliate center.
        if (loc.startsWith('/affiliate') && user.userType != 'affiliate') {
          return '/home';
        }
        // Vendor portal access
        // sent to their own home rather than shown a vendor console.
        if (loc.startsWith('/vendor') && user.userType != 'vendor') {
          return '/home';
        }
        // The supplier portal is exclusive to suppliers.
        if (loc.startsWith('/supplier') && user.userType != 'supplier') {
          return '/home';
        }
        // The delivery portal is exclusive to delivery partners.
        if (loc.startsWith('/delivery') && user.userType != 'delivery') {
          return '/home';
        }
        return null;
      }

      // Signed out.
      if (isPublic) {
        // Code-verification / reset screens only make sense mid-flow.
        final pendingReset = auth.hasPendingReset;
        final hasToken = (auth.resetToken ?? '').isNotEmpty;
        if (loc == '/reset-password' && !hasToken) return '/forgot-password';
        if (loc == '/verify-code' && !pendingReset) return '/forgot-password';
        return null;
      }
      // For protected routes when signed out, send to home (marketplace) instead of login
      // Authentication should only be required when user takes action
      if (_isPublicRoute(loc)) return null;
      return '/home';
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-code',
        builder: (_, __) => const VerificationCodeScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const MainNavigationScreen()),
      // Supplier portal. Deliberately outside /admin so the super-admin-only
      // guard below never bounces a supplier away from their own dashboard.
      //
      // Every route is mounted inside SupplierShell so the grouped nav, header
      // web DashboardLayout
      // paths match supplier nav groups
      // exactly; pages without an API are routed to an explicit unavailable
      // state instead of mock numbers.
      GoRoute(
        path: '/supplier',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier',
              child: SupplierOverviewScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/products',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/products',
              child: SupplierProductsScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/inventory',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/inventory',
              child: SupplierInventoryScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/orders',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/orders',
              child: SupplierOrdersScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/settings',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/settings',
              child: SupplierProfileScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/notifications',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/notifications',
              child: SupplierNotificationsScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/messages',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/messages',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/supplier/support',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/support',
              child: MessagesScreen(),
            ),
      ),
      // Legacy alias kept so older deep links keep working.
      GoRoute(
        path: '/supplier/profile',
        redirect: (_, __) => '/supplier/settings',
      ),
      GoRoute(
        path: '/supplier/search',
        builder:
            (context, state) => const SupplierShell(
              path: '/supplier/search',
              child: SearchScreen(),
            ),
      ),
      for (final page in _unavailableSupplierPages)
        GoRoute(
          path: page.path,
          builder:
              (context, state) => SupplierShell(
                path: page.path,
                child: FeatureUnavailableScreen(
                  feature: page.title,
                  detail: page.detail,
                  eyebrow: 'SUPPLIER PLATFORM',
                  icon: page.icon,
                ),
              ),
        ),
      GoRoute(
        path: '/affiliate',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate',
              child: AffiliateDashboardScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/profile',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/profile',
              child: AffiliateProfileScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/settings',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/settings',
              child: AffiliateSettingsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/products',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/products',
              child: AffiliateProductsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/campaigns',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/campaigns',
              child: AffiliateCampaignsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/links',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/links',
              child: AffiliateLinksScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/stats',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/stats',
              child: AffiliateStatsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/earnings',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/earnings',
              child: AffiliateEarningsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/payouts',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/payouts',
              child: AffiliatePayoutsScreen(),
            ),
      ),
      // The web console names the wallet and withdrawal destinations
      // /affiliate/wallet and /affiliate/withdrawals. Both are served here, and
      // /affiliate/payouts stays as the older alias for the withdrawal centre.
      GoRoute(
        path: '/affiliate/wallet',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/wallet',
              child: AffiliateWalletScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/withdrawals',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/withdrawals',
              child: AffiliatePayoutsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/notifications',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/notifications',
              child: AffiliateNotificationsScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/messages',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/messages',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/affiliate/support',
        builder:
            (context, state) => const AffiliateShell(
              path: '/affiliate/support',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin', child: OverviewScreen()),
      ),
      GoRoute(
        path: '/admin/messages',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/messages',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/analytics',
              child: AnalyticsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/ledger',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/ledger', child: LedgerScreen()),
      ),
      GoRoute(
        path: '/admin/commission-rules',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/commission-rules',
              child: CommissionRulesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/risk',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/risk', child: RiskScreen()),
      ),
      GoRoute(
        path: '/admin/supplier-acquisition',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/supplier-acquisition',
              child: AcquisitionScreen(type: 'supplier'),
            ),
      ),
      GoRoute(
        path: '/admin/vendor-acquisition',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/vendor-acquisition',
              child: AcquisitionScreen(type: 'vendor'),
            ),
      ),
      GoRoute(
        path: '/admin/users',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/users', child: UsersScreen()),
      ),
      GoRoute(
        path: '/admin/vendors',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/vendors',
              child: VendorsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/suppliers',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/suppliers',
              child: SuppliersScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/buyers',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/buyers', child: BuyersScreen()),
      ),
      GoRoute(
        path: '/admin/account',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/account',
              child: AccountScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/affiliates',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/affiliates',
              child: AffiliatesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/products',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/products',
              child: ProductsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/categories',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/categories',
              child: CategoriesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/orders',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/orders', child: OrdersScreen()),
      ),
      GoRoute(
        path: '/admin/payments',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/payments',
              child: PaymentsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/transactions',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/transactions',
              child: TransactionsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/commissions',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/commissions',
              child: CommissionsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/deliveries',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/deliveries',
              child: DeliveriesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/refunds',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/refunds',
              child: RefundsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/disputes',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/disputes',
              child: DisputesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/advertising',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/advertising',
              child: AdvertisingScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/subscriptions',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/subscriptions',
              child: SubscriptionsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/reports',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/reports',
              child: ReportsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/recommendations',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/recommendations',
              child: RecommendationsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/matching',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/matching',
              child: MatchingScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/trust',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/trust', child: TrustScreen()),
      ),
      GoRoute(
        path: '/admin/reviews',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/reviews',
              child: ReviewsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/notifications',
              child: NotificationsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/languages',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/languages',
              child: LanguagesScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/locations',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/locations',
              child: LocationsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/audit-logs',
              child: AuditLogsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/security',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/security',
              child: SecurityScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/system',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/system', child: SystemScreen()),
      ),
      GoRoute(
        path: '/admin/settings',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/settings',
              child: SettingsScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/support',
        builder:
            (context, state) => const AdminShell(
              path: '/admin/support',
              child: SupportScreen(),
            ),
      ),
      GoRoute(
        path: '/admin/search',
        builder:
            (context, state) =>
                const AdminShell(path: '/admin/search', child: SearchScreen()),
      ),

      // ---------- Vendor portal ----------
      // Every vendor route is wrapped in the vendor shell, which mirrors the
      // admin shell layout
      GoRoute(
        path: '/vendor',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor',
              child: VendorOverviewScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/products',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/products',
              child: VendorProductsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/profile',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/profile',
              child: VendorProfileScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/orders',
        builder:
            (context, state) => VendorShell(
              path: '/vendor/orders',
              child: VendorOrdersScreen(
                initialOrderId: state.uri.queryParameters['order'],
              ),
            ),
      ),
      GoRoute(
        path: '/vendor/sales',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/sales',
              child: VendorSalesScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/notifications',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/notifications',
              child: VendorNotificationsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/messages',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/messages',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/support',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/support',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/settings',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/settings',
              child: VendorSettingsScreen(),
            ),
      ),
      // ---- Vendor destinations that the API actually serves ----
      //
      // Each of these reads a real vendor-scoped route, so the numbers on
      // screen are the platform's own records.
      GoRoute(
        path: '/vendor/inventory',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/inventory',
              child: VendorProductsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/categories',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/categories',
              child: VendorCategoriesScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/purchases',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/purchases',
              child: VendorPurchasesScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/analytics',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/analytics',
              child: VendorAnalyticsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/payouts',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/payouts',
              child: VendorPayoutsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/transactions',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/transactions',
              child: VendorTransactionsScreen(),
            ),
      ),
      GoRoute(
        path: '/vendor/reviews',
        builder:
            (context, state) => const VendorShell(
              path: '/vendor/reviews',
              child: VendorReviewsScreen(),
            ),
      ),
      // ---- Vendor destinations the web console fakes ----
      //
      // The web app renders these pages from hard-coded `localStorage` seed rows
      // rather than an API call, so there is nothing real to show. The
      // navigation stays identical and the page says so plainly instead of
      // inventing staff, customers or shipment records.
      for (final page in _unavailableVendorPages)
        GoRoute(
          path: page.path,
          builder:
              (context, state) => VendorShell(
                path: page.path,
                child: FeatureUnavailableScreen(
                  feature: page.title,
                  detail: page.detail,
                  eyebrow: 'SELLER PLATFORM',
                  icon: page.icon,
                ),
              ),
        ),
      // Seller upgrade. The web console files this page under
      // /admin/become-seller; it is also reachable at /become-seller because
      // the upgrade applies to a buyer account, not an administrator.
      GoRoute(
        path: '/become-seller',
        builder: (context, state) => const BecomeSellerScreen(),
      ),
      GoRoute(
        path: '/admin/become-seller',
        builder: (context, state) => const BecomeSellerScreen(),
      ),
      GoRoute(
        path: '/buyer/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/buyer/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Delivery portal. Mirrors the web app's `DeliveryLayout`, where every
      // destination hangs off /delivery and is guarded to delivery accounts.
      GoRoute(
        path: '/delivery',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery',
              child: DeliveryDashboardScreen(),
            ),
      ),
      GoRoute(
        path: '/delivery/deliveries',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery/deliveries',
              child: DeliveryDeliveriesScreen(),
            ),
      ),
      GoRoute(
        path: '/delivery/earnings',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery/earnings',
              child: DeliveryEarningsScreen(),
            ),
      ),
      GoRoute(
        path: '/delivery/history',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery/history',
              child: DeliveryHistoryScreen(),
            ),
      ),
      GoRoute(
        path: '/delivery/messages',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery/messages',
              child: MessagesScreen(),
            ),
      ),
      GoRoute(
        path: '/delivery/settings',
        builder:
            (context, state) => const DeliveryShell(
              path: '/delivery/settings',
              child: DeliverySettingsScreen(),
            ),
      ),
    ],
  );
});
