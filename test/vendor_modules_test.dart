import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mvec_mobile/core/api_client.dart';
import 'package:mvec_mobile/core/theme.dart';
import 'package:mvec_mobile/features/vendor/models/vendor_finance.dart';
import 'package:mvec_mobile/features/vendor/models/vendor_notification.dart';
import 'package:mvec_mobile/features/vendor/models/vendor_order.dart';
import 'package:mvec_mobile/features/vendor/models/vendor_settings.dart';
import 'package:mvec_mobile/features/vendor/screens/vendor_settings_screen.dart';
import 'package:mvec_mobile/features/vendor/services/vendor_finance_service.dart';
import 'package:mvec_mobile/features/vendor/services/vendor_notification_service.dart';
import 'package:mvec_mobile/features/vendor/services/vendor_order_service.dart';
import 'package:mvec_mobile/features/vendor/services/vendor_settings_service.dart';
import 'package:mvec_mobile/features/vendor/vendor_dependencies.dart';

/// In-memory stand-ins for the vendor services.
///
/// The app has no local data source, so these live in the test file rather than
/// in `lib/`: they exist to drive the screens and to assert the validation rules
/// that used to live in the deleted mock services.
class _FakeOrderService implements VendorOrderService {
  final List<VendorOrder> seed = [
    VendorOrder(
      id: 'order-1',
      number: 'MV-4821',
      placedAt: DateTime(2026, 9, 21),
      buyerName: 'Aline Uwase',
      status: VendorOrderStatus.pending,
      paid: true,
      subtotal: 120000,
      commission: 12000,
      shipping: 2000,
      deliveryOtp: '4321',
      items: const [
        VendorOrderItem(
          productId: 'p1',
          name: 'Maize flour 25kg',
          unitPrice: 120000,
          quantity: 1,
        ),
      ],
    ),
  ];

  @override
  Future<VendorOrderPage> orders({
    VendorOrderStatus? status,
    String search = '',
  }) async => VendorOrderPage(
    orders: seed
        .where((order) => status == null || order.status == status)
        .toList(),
    counts: {null: seed.length},
  );

  @override
  Future<VendorOrder> order(String id) async =>
      seed.firstWhere((order) => order.id == id);

  @override
  Future<VendorOrder> updateStatus(
    String id,
    VendorOrderStatus status, {
    String? trackingCode,
    String? courierName,
    String? deliveryOtp,
  }) async {
    validateStatusChange(
      status,
      trackingCode: trackingCode,
      deliveryOtp: deliveryOtp,
    );
    final index = seed.indexWhere((order) => order.id == id);
    final current = seed[index];
    // Escrow releases on confirmed delivery, never on dispatch.
    seed[index] = _copyWith(
      current,
      status: status,
      trackingCode: trackingCode,
      deliveryOtp: deliveryOtp,
    );
    return seed[index];
  }

  @override
  Future<VendorOrder> cancel(String id, {String? reason}) async {
    final index = seed.indexWhere((order) => order.id == id);
    seed[index] = _copyWith(seed[index], status: VendorOrderStatus.cancelled);
    return seed[index];
  }

  static VendorOrder _copyWith(
    VendorOrder order, {
    VendorOrderStatus? status,
    String? trackingCode,
    String? deliveryOtp,
  }) => VendorOrder(
    id: order.id,
    number: order.number,
    placedAt: order.placedAt,
    buyerName: order.buyerName,
    buyerPhone: order.buyerPhone,
    buyerEmail: order.buyerEmail,
    deliveryAddress: order.deliveryAddress,
    deliveryNote: order.deliveryNote,
    paymentMethod: order.paymentMethod,
    paid: order.paid,
    subtotal: order.subtotal,
    commission: order.commission,
    shipping: order.shipping,
    status: status ?? order.status,
    items: order.items,
    courierName: order.courierName,
    trackingCode: trackingCode ?? order.trackingCode,
    deliveryOtp: deliveryOtp ?? order.deliveryOtp,
    timeline: order.timeline,
    disputeOpen: order.disputeOpen,
  );
}

class _FakeFinanceService implements VendorFinanceService {
  VendorFinanceSummary _summary = const VendorFinanceSummary(
    grossRevenue: 1200000,
    commission: 120000,
    netEarnings: 1080000,
    escrowHeld: 300000,
    availablePayout: 1500000,
  );

  final List<PayoutRequest> requests = [];

  @override
  Future<VendorFinanceSummary> summary() async => _summary;

  @override
  Future<List<LedgerEntry>> ledger({LedgerEntryKind? kind, int limit = 50}) async =>
      const [];

  @override
  Future<List<PayoutRequest>> payouts() async => requests;

  @override
  Future<PayoutRequest> requestPayout({
    required num amount,
    required PayoutMethod method,
    required String destination,
    String? note,
  }) async {
    validatePayoutRequest(
      amount: amount,
      method: method,
      destination: destination,
      available: _summary.availablePayout,
    );
    final request = PayoutRequest(
      id: 'payout-${requests.length + 1}',
      amount: amount,
      method: method,
      destination: destination.trim(),
      status: 'PENDING',
      requestedAt: DateTime(2026, 9, 22),
    );
    requests.add(request);
    // A pending payout is excluded from the withdrawable balance.
    _summary = VendorFinanceSummary(
      grossRevenue: _summary.grossRevenue,
      commission: _summary.commission,
      netEarnings: _summary.netEarnings,
      escrowHeld: _summary.escrowHeld,
      availablePayout: _summary.availablePayout - amount,
      pendingPayouts: _summary.pendingPayouts + amount,
    );
    return request;
  }
}

class _FakeNotificationService implements VendorNotificationService {
  final List<VendorNotification> _items = [
    VendorNotification(
      id: 'n1',
      at: DateTime(2026, 9, 22),
      category: NotificationCategory.order,
      title: 'New order',
      body: 'Order MV-4821 was placed.',
    ),
  ];

  @override
  Future<List<VendorNotification>> notifications({
    NotificationCategory? category,
  }) async =>
      _items.where((item) => category == null || item.category == category).toList();

  @override
  Future<VendorNotification> setRead(String id, bool read) async {
    final index = _items.indexWhere((item) => item.id == id);
    _items[index] = _items[index].copyWith(read: read);
    return _items[index];
  }
}

class _FakeSettingsService implements VendorSettingsService {
  VendorStoreSettings _settings = const VendorStoreSettings(
    storeName: 'Test Store',
    staff: [
      VendorStaffMember(
        id: 'owner-1',
        name: 'Owner',
        email: 'owner@example.rw',
        role: StaffRole.owner,
        permissions: {},
      ),
      VendorStaffMember(
        id: 'staff-1',
        name: 'Staff Member',
        email: 'staff@example.rw',
        role: StaffRole.staff,
        permissions: {},
      ),
    ],
  );

  @override
  Future<VendorStoreSettings> settings() async => _settings;

  @override
  Future<VendorStoreSettings> save(VendorStoreSettings settings) async {
    _settings = settings;
    return _settings;
  }

  @override
  Future<VendorStoreSettings> inviteStaff({
    required VendorStaffMember member,
    required String password,
  }) async {
    _settings = _settings.copyWith(
      staff: [..._settings.staff, member],
    );
    return _settings;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<VendorStoreSettings> setStaffActive(String id, bool active) async {
    _settings = _settings.copyWith(
      staff: [
        for (final member in _settings.staff)
          if (member.id == id) member.copyWith(active: active) else member,
      ],
    );
    return _settings;
  }
}

void main() {
  test('vendor modules resolve to the live API services', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(vendorOrderModuleProvider),
      isA<ApiVendorOrderService>(),
    );
    expect(
      container.read(vendorFinanceModuleProvider),
      isA<ApiVendorFinanceService>(),
    );
    expect(
      container.read(vendorNotificationModuleProvider),
      isA<ApiVendorNotificationService>(),
    );
    expect(
      container.read(vendorSettingsModuleProvider),
      isA<ApiVendorSettingsService>(),
    );
  });

  test('orders progress through tracking and buyer OTP confirmation', () async {
    final service = _FakeOrderService();
    final pending = service.seed.first;

    final processing = await service.updateStatus(
      pending.id,
      VendorOrderStatus.processing,
    );
    expect(processing.status, VendorOrderStatus.processing);

    await expectLater(
      service.updateStatus(pending.id, VendorOrderStatus.shipped),
      throwsA(isA<ApiException>()),
    );

    final shipped = await service.updateStatus(
      pending.id,
      VendorOrderStatus.shipped,
      trackingCode: 'TRACK-001',
    );
    expect(shipped.trackingCode, 'TRACK-001');
    expect(shipped.escrowReleased, isFalse);

    // A missing code is rejected locally; whether the code itself is correct is
    // the backend's call, since the app never holds the buyer's expected OTP.
    await expectLater(
      service.updateStatus(pending.id, VendorOrderStatus.delivered),
      throwsA(isA<ApiException>()),
    );

    final delivered = await service.updateStatus(
      pending.id,
      VendorOrderStatus.delivered,
      deliveryOtp: '4321',
    );
    expect(delivered.escrowReleased, isTrue);
  });

  test(
    'payout validation uses the balance shown in the finance summary',
    () async {
      final service = _FakeFinanceService();
      final before = await service.summary();
      expect(before.isConsistent, isTrue);

      await expectLater(
        service.requestPayout(
          amount: before.availablePayout + 1,
          method: PayoutMethod.mtnMomo,
          destination: '+250788000001',
        ),
        throwsA(isA<ApiException>()),
      );

      final payout = await service.requestPayout(
        amount: 120000,
        method: PayoutMethod.mtnMomo,
        destination: '+250788000001',
      );
      expect(payout.isPending, isTrue);
      expect(
        (await service.summary()).availablePayout,
        before.availablePayout - payout.amount,
      );
    },
  );

  test('payouts below the platform minimum are rejected', () {
    expect(
      () => validatePayoutRequest(
        amount: kMinPayoutAmount - 1,
        method: PayoutMethod.mtnMomo,
        destination: '+250788000001',
        available: 1000000,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('payouts need a destination', () {
    expect(
      () => validatePayoutRequest(
        amount: 120000,
        method: PayoutMethod.mtnMomo,
        destination: '   ',
        available: 1000000,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('notifications and settings round-trip mutations', () async {
    final notifications = _FakeNotificationService();
    final firstUnread = (await notifications.notifications()).firstWhere(
      (item) => !item.read,
    );
    expect((await notifications.setRead(firstUnread.id, true)).read, isTrue);

    final settings = _FakeSettingsService();
    final profile = await settings.settings();
    final updated = await settings.save(
      profile.copyWith(storeName: 'Store Updated'),
    );
    expect((await settings.settings()).storeName, updated.storeName);

    final staff = profile.staff.firstWhere((member) => !member.isOwner);
    final changed = await settings.setStaffActive(staff.id, false);
    expect(
      changed.staff.firstWhere((member) => member.id == staff.id).active,
      isFalse,
    );
  });

  test('shipping summaries format whole RWF amounts safely', () {
    const flat = ShippingRule(
      id: 'flat',
      name: 'Standard',
      type: ShippingRuleType.flat,
      amount: 2000,
      etaDays: 2,
    );
    const free = ShippingRule(
      id: 'free',
      name: 'Free delivery',
      type: ShippingRuleType.free,
      minimumOrder: 50000,
      etaDays: 1,
    );

    expect(flat.summary, '2,000 · 2 days');
    expect(free.summary, 'Free above 50,000');
  });

  testWidgets('business and delivery section renders shipping options', (
    tester,
  ) async {
    const settings = VendorStoreSettings(
      storeName: 'Test Store',
      hours: OperatingHours([OperatingDay(label: 'Monday', open: true)]),
      shippingRules: [
        ShippingRule(
          id: 'ship-standard',
          name: 'Kigali standard',
          type: ShippingRuleType.flat,
          amount: 2000,
          etaDays: 2,
        ),
        ShippingRule(
          id: 'ship-free',
          name: 'Free delivery',
          type: ShippingRuleType.free,
          minimumOrder: 50000,
          etaDays: 1,
        ),
      ],
      defaultShippingRuleId: 'ship-standard',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorStoreSettingsProvider.overrideWith((ref) async => settings),
          vendorSettingsModuleProvider.overrideWith(
            (ref) => _FakeSettingsService(),
          ),
        ],
        child: MaterialApp(
          theme: lightAppTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: VendorSettingsScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Business & delivery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kigali standard · 2,000 · 2 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
