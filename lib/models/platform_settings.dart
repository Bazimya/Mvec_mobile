class PlatformSettings {
  const PlatformSettings({
    this.marketplaceName = 'MVEC Marketplace',
    this.defaultCurrency = 'RWF',
    this.vendorApproval = 'Manual',
    this.commissionPercent = 10,
    this.cancelWindow = '24 hours',
    this.reviewsModeration = 'Required',
    this.orderNotifications = 'Enabled',
    this.shippingNotifications = 'Enabled',
    this.payoutNotifications = 'Disabled',
  });

  final String marketplaceName;
  final String defaultCurrency;
  final String vendorApproval;
  final num commissionPercent;
  final String cancelWindow;
  final String reviewsModeration;
  final String orderNotifications;
  final String shippingNotifications;
  final String payoutNotifications;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    final data =
        json['settings'] is Map
            ? Map<String, dynamic>.from(json['settings'])
            : json;
    return PlatformSettings(
      marketplaceName:
          data['marketplaceName']?.toString() ?? 'MVEC Marketplace',
      defaultCurrency: data['defaultCurrency']?.toString() ?? 'RWF',
      vendorApproval: data['vendorApproval']?.toString() ?? 'Manual',
      commissionPercent:
          data['commissionPercent'] is num
              ? data['commissionPercent'] as num
              : num.tryParse('${data['commissionPercent'] ?? 10}') ?? 10,
      cancelWindow: data['cancelWindow']?.toString() ?? '24 hours',
      reviewsModeration: data['reviewsModeration']?.toString() ?? 'Required',
      orderNotifications: data['orderNotifications']?.toString() ?? 'Enabled',
      shippingNotifications:
          data['shippingNotifications']?.toString() ?? 'Enabled',
      payoutNotifications:
          data['payoutNotifications']?.toString() ?? 'Disabled',
    );
  }

  Map<String, dynamic> toJson() => {
    'marketplaceName': marketplaceName,
    'defaultCurrency': defaultCurrency,
    'vendorApproval': vendorApproval,
    'commissionPercent': commissionPercent,
    'cancelWindow': cancelWindow,
    'reviewsModeration': reviewsModeration,
    'orderNotifications': orderNotifications,
    'shippingNotifications': shippingNotifications,
    'payoutNotifications': payoutNotifications,
  };
}
