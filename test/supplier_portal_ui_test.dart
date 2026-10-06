// Supplier portal UI parity against the live `SupplierWorkspaceService`
// contract.
//
// These cases used to live in `demo_mode_test.dart` and only ran under
// `--dart-define=DEMO_MODE=true`. The demo service is gone, so they now drive
// the real provider with an in-memory double instead: the widgets, field sets
// and breakpoints under test are unchanged, only the data source moved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mvec_mobile/features/supplier/data/supplier_workspace.dart';
import 'package:mvec_mobile/main.dart';
import 'package:mvec_mobile/models/user.dart';
import 'package:mvec_mobile/providers/auth_provider.dart';
import 'package:mvec_mobile/screens/suppliers/supplier_overview_screen.dart';
import 'package:mvec_mobile/screens/suppliers/supplier_shell.dart';

import 'support/fake_marketplace_services.dart';

/// An in-memory `SupplierWorkspaceService` shaped exactly like the API
/// responses, so the shell renders the same widgets the backend would produce.
class _FakeSupplierWorkspaceService implements SupplierWorkspaceService {
  final List<SupplierProduct> _products = [
    const SupplierProduct(
      id: 'sp-1',
      name: 'Arabica Coffee Beans',
      category: 'Beverages',
      description: 'Washed specialty beans, medium roast.',
      imageUrl: 'https://example.test/beans.png',
      price: 12500,
      stock: 84,
      status: 'ACTIVE',
      minimumOrderQuantity: 10,
      bulkDiscount: 8,
    ),
  ];

  final List<SupplierOrder> _orders = [
    SupplierOrder(
      id: 'MV-4821',
      buyer: 'Kigali Roasters Ltd',
      product: 'Arabica Coffee Beans',
      quantity: 12,
      total: 150000,
      status: 'Pending',
      requestedAt: DateTime(2026, 3, 4),
    ),
  ];

  @override
  Future<List<SupplierProduct>> products() async => List.unmodifiable(_products);

  @override
  Future<List<SupplierOrder>> orders() async => List.unmodifiable(_orders);

  @override
  Future<List<SupplierNotice>> notifications() async => const [];

  @override
  Future<SupplierProfile> profile() async => const SupplierProfile(
    id: 's-1',
    businessName: 'Nyamasheke Growers',
    email: 'supplier@example.test',
    phone: '0799000000',
    address: 'Kigali',
    orderNotifications: true,
    stockNotifications: true,
  );

  @override
  Future<void> saveProduct(SupplierProduct product) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> updateStock(String id, int stock) async {}

  @override
  Future<void> updateOrderStatus(String id, String status) async {
    final index = _orders.indexWhere((order) => order.id == id);
    if (index >= 0) {
      _orders[index] = SupplierOrder(
        id: _orders[index].id,
        buyer: _orders[index].buyer,
        product: _orders[index].product,
        quantity: _orders[index].quantity,
        total: _orders[index].total,
        status: status,
        requestedAt: _orders[index].requestedAt,
      );
    }
  }

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> saveProfile(
    SupplierProfile profile, {
    required bool isNewProfile,
  }) async {}
}

/// Boots the app as a supplier with the workspace service replaced by
/// [_FakeSupplierWorkspaceService].
Future<void> _pumpSupplier(
  WidgetTester tester, {
  Size size = const Size(800, 600),
}) async {
  // `size` is a logical size; the view is configured in physical pixels.
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _StubAuthController(
            UserRecord(
              id: 'u1',
              fullname: 'Test Supplier',
              email: 'supplier@example.test',
              role: 'supplier',
            ),
          ),
        ),
        supplierWorkspaceServiceProvider.overrideWithValue(
          _FakeSupplierWorkspaceService(),
        ),
        ...marketplaceOverrides(),
      ],
      child: const MvecApp(),
    ),
  );
  // The marketplace is the public entry point, so a supplier opens the portal
  // from the account sheet rather than being redirected there.
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Supplier dashboard'));
  await _pumpFrames(tester);
}

/// Pumps a bounded number of frames.
///
/// The supplier portal keeps live providers alive (their spinners never settle)
/// so `pumpAndSettle` times out. Page transitions and drawer animations need
/// several frames to finish, so step instead of settling.
Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 300),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

class _StubAuthController extends AuthController {
  _StubAuthController(this.user);

  final UserRecord user;

  @override
  AuthState build() =>
      AuthState(session: AuthSession(token: 'test-token', user: user));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('a supplier lands on the portal, not the marketplace', (
    tester,
  ) async {
    await _pumpSupplier(tester);

    expect(find.byType(SupplierOverviewScreen), findsOneWidget);
  });

  testWidgets('a supplier can advance a pending order', (tester) async {
    await _pumpSupplier(tester);

    // The 800x600 viewport is below the 900pt breakpoint, so the shell renders
    // the bottom bar rather than the permanent sidebar.
    await tester.tap(find.text('Orders'));
    await _pumpFrames(tester);
    expect(find.text('Confirm order'), findsOneWidget);

    await tester.tap(find.text('Confirm order'));
    await _pumpFrames(tester);
    expect(find.text('Confirmed'), findsWidgets);
  });

  testWidgets('the product form collects only the web fields', (tester) async {
    await _pumpSupplier(tester);

    await tester.tap(find.text('Products'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Add wholesale product'));
    await _pumpFrames(tester);

    // The seven fields the web supplier form collects.
    const webFields = [
      'Product name *',
      'Category *',
      'Wholesale price (RWF) *',
      'Minimum order quantity *',
      'Stock *',
      'Bulk discount (%) *',
      'Description',
    ];
    for (final label in webFields) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'the web form has a "$label" field',
      );
    }

    // Fields the web form does not have must not be asked for.
    for (final removed in [
      'Unit',
      'Retail price',
      'Main image URL',
      'Gallery image links',
      'Status',
    ]) {
      expect(
        find.text(removed),
        findsNothing,
        reason: '"$removed" is not part of the web supplier form',
      );
    }

    // Description is the only optional field on the web form.
    expect(find.text('Optional'), findsOneWidget);
  });

  testWidgets('the shell swaps sidebar for bottom nav at 900pt', (
    tester,
  ) async {
    // Wide: the web's permanent .dashboard-sidebar, and no bottom bar.
    await _pumpSupplier(tester, size: const Size(1200, 800));

    expect(find.byType(SupplierSidebar), findsOneWidget);
    expect(find.byType(SupplierBottomBar), findsNothing);

    // Nav groups are collapsible, so open the catalogue group first.
    expect(find.text('Wholesale Products'), findsNothing);
    await tester.tap(find.text('CATALOG & ORDERS'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Wholesale Products'));
    await _pumpFrames(tester);
    expect(find.text('Arabica Coffee Beans'), findsOneWidget);

    // Narrow: the bottom bar takes over and the sidebar is gone.
    tester.view.physicalSize = const Size(420 * 2, 900 * 2);
    await _pumpFrames(tester);
    expect(find.byType(SupplierBottomBar), findsOneWidget);
    expect(find.byType(SupplierSidebar), findsNothing);
    expect(find.byTooltip('Open supplier navigation'), findsOneWidget);
  });

  testWidgets('the "More" sheet exposes the rest of the supplier nav', (
    tester,
  ) async {
    await _pumpSupplier(tester, size: const Size(420, 900));

    // The four primary destinations are pinned; the rest live behind More.
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Transactions'), findsNothing);

    await tester.tap(find.text('More'));
    await _pumpFrames(tester);

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('MVEC Support'), findsOneWidget);
  });

  test('empty credentials are rejected before any network call', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login('   ', '');

    expect(ok, isFalse);
    expect(container.read(authControllerProvider).session, isNull);
  });
}
