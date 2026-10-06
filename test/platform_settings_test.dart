import 'package:flutter_test/flutter_test.dart';
import 'package:mvec_mobile/models/platform_settings.dart';

void main() {
  group('PlatformSettings', () {
    test('parses settings envelopes and serializes the editable fields', () {
      final settings = PlatformSettings.fromJson({
        'settings': {
          'marketplaceName': 'MVEC Rwanda',
          'defaultCurrency': 'RWF',
          'vendorApproval': 'Manual',
          'commissionPercent': 12.5,
          'cancelWindow': '48 hours',
          'reviewsModeration': 'Required',
          'orderNotifications': 'Enabled',
          'shippingNotifications': 'Disabled',
          'payoutNotifications': 'Enabled',
        },
      });

      expect(settings.marketplaceName, 'MVEC Rwanda');
      expect(settings.commissionPercent, 12.5);
      expect(settings.toJson()['shippingNotifications'], 'Disabled');
      expect(settings.toJson()['payoutNotifications'], 'Enabled');
    });

    test('applies defaults when the backend omits optional settings', () {
      final settings = PlatformSettings.fromJson(const {});

      expect(settings.marketplaceName, 'MVEC Marketplace');
      expect(settings.commissionPercent, 10);
      expect(settings.defaultCurrency, 'RWF');
    });
  });
}
