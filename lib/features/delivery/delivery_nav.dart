import '../../core/nav_items.dart';

/// Delivery portal navigation mirroring the web frontend's `deliveryNavGroups`
/// in `src/data/navItems.js`:
///
///   Overview -> Dashboard
///   Work     -> My Deliveries, Earnings, History
///   Support  -> Messages, Settings
class DeliveryNav {
  DeliveryNav._();

  static const root = '/delivery';

  static const groups = <NavGroup>[
    NavGroup('Overview', [NavItem('Dashboard', '/delivery', 'grid')]),
    NavGroup('Work', [
      NavItem('My Deliveries', '/delivery/deliveries', 'box'),
      NavItem('Earnings', '/delivery/earnings', 'wallet'),
      NavItem('History', '/delivery/history', 'chart'),
    ]),
    NavGroup('Support', [
      NavItem('Messages', '/delivery/messages', 'users'),
      NavItem('Settings', '/delivery/settings', 'settings'),
    ]),
  ];

  static List<NavItem> get all => [for (final g in groups) ...g.items];

  /// The compact primary set the web app pins to the mobile bottom bar
  /// (`mobilePrimaryByRole.delivery`), followed by the shell's "More" entry.
  static const bottomNav = <NavItem>[
    NavItem('Dashboard', '/delivery', 'grid'),
    NavItem('My Deliveries', '/delivery/deliveries', 'box'),
    NavItem('Earnings', '/delivery/earnings', 'wallet'),
    NavItem('History', '/delivery/history', 'chart'),
  ];

  static String? groupFor(String path) {
    for (final g in groups) {
      if (g.items.any(
        (i) => i.path == path || (path.startsWith(i.path) && i.path != root),
      )) {
        return g.label;
      }
    }
    return null;
  }
}
