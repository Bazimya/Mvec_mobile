import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils/app_theme.dart';
import '../../../../models/user.dart';
import '../../../../providers/auth_provider.dart';
import '../../data/models/category_model.dart';
import '../providers/commerce_provider.dart';
import '../providers/home_provider.dart';
import 'categories_screen.dart';
import 'deals_screen.dart';
import 'for_you_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'product_navigation.dart';
import 'search_screen.dart';
import 'shop_screen.dart';
import 'vendors_screen.dart';

/// Sky-blue accent used by the active tab and the sliding indicator.
const Color kActiveBlue = Color(0xFF55C9F2);

/// Root marketplace navigation container.
///
/// Floating bottom bar for the four primary tabs (Home, Shop, For You, Deals)
/// plus a top bar carrying search, wishlist, cart and account actions, and an
/// expandable category bar. The destinations that do not fit in the bottom bar
/// — All Categories, Vendors and Orders — stay reachable from the category bar
/// so nothing from the storefront top-menu design is lost.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  Category? _selectedCategory;
  bool _categoriesExpanded = true;

  void _select(int index) => setState(() => _currentIndex = index);

  void _selectCategory(Category? category) {
    setState(() {
      _selectedCategory = category;
      // Jump to the Shop tab so the filtered catalog shows instantly.
      _currentIndex = 1;
    });
  }

  void _openAllProducts() {
    setState(() {
      _selectedCategory = null;
      _currentIndex = 1;
    });
  }

  // ---------------------------------------------------------------------------
  // Full-page destinations.
  // ---------------------------------------------------------------------------

  void _pushPage(Widget child, {String? title}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(title ?? '')),
          body: SafeArea(child: child),
        ),
      ),
    );
  }

  void _openSearch() =>
      _pushPage(const SearchScreen(), title: 'Search');

  void _openVendors() => _pushPage(const VendorsScreen(), title: 'Vendors');

  void _openOrders() => _pushPage(const OrdersScreen(), title: 'My Orders');

  void _openCategories() {
    _pushPage(
      CategoriesScreen(onCategoryTap: (category) {
        _selectCategory(category);
        Navigator.of(context).pop();
      }),
      title: 'All Categories',
    );
  }

  void _openWishlist(BuildContext context) =>
      openWishlist(context, context.read<CommerceProvider>());

  void _openCart(BuildContext context) =>
      openCart(context, context.read<CommerceProvider>());

  // ---------------------------------------------------------------------------
  // Account sheet: identity, a shortcut to the dashboard for admins and sign out.
  // ---------------------------------------------------------------------------

  Future<void> _openProfile() async {
    final user = ref.read(currentUserProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _AccountHeader(user: user),
            const Divider(height: 26),
            if (user != null && user.userType == 'super_admin')
              _SheetAction(
                icon: Icons.dashboard_outlined,
                label: 'Go to dashboard',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pop();
                },
              ),
            _SheetAction(
              icon: Icons.shopping_bag_outlined,
              label: 'My orders',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openOrders();
              },
            ),
            _SheetAction(
              icon: Icons.favorite_border,
              label: 'My wishlist',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openWishlist(context);
              },
            ),
            _SheetAction(
              icon: Icons.logout,
              label: 'Sign out',
              destructive: true,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(authControllerProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavigation(context, provider.categories),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: <Widget>[
                  HomeScreen(
                    onBrowseAll: _openAllProducts,
                    onCategoryTap: _selectCategory,
                  ),
                  ShopScreen(
                    key: ValueKey<int?>(_selectedCategory?.id),
                    initialCategory: _selectedCategory,
                  ),
                  const ForYouScreen(),
                  const DealsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  // ---------------------------------------------------------------------------
  // Top navigation: back, search trigger, wishlist/cart badges, account.
  // ---------------------------------------------------------------------------

  Widget _buildTopNavigation(
    BuildContext context,
    List<Category> categories,
  ) {
    final commerce = context.watch<CommerceProvider>();
    final cartCount = commerce.cartItems.fold<int>(
      0,
      (count, item) => count + item.quantity,
    );

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                Expanded(child: _SearchTrigger(onTap: _openSearch)),
                _TopBarAction(
                  icon: Icons.favorite_border,
                  tooltip: 'Wishlist',
                  count: commerce.wishlistItems.length,
                  countKey: 'home-wishlist-count',
                  onPressed: () => _openWishlist(context),
                ),
                _TopBarAction(
                  icon: Icons.shopping_bag_outlined,
                  tooltip: 'Cart',
                  count: cartCount,
                  countKey: 'home-cart-count',
                  onPressed: () => _openCart(context),
                ),
                IconButton(
                  tooltip: 'Account',
                  icon: const Icon(Icons.person_outline),
                  onPressed: _openProfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _CategoriesBar(
            categories: categories,
            selected: _selectedCategory,
            expanded: _categoriesExpanded,
            onToggleExpanded: () =>
                setState(() => _categoriesExpanded = !_categoriesExpanded),
            onSelected: _selectCategory,
            onOpenAllCategories: _openCategories,
            onOpenVendors: _openVendors,
            onOpenOrders: _openOrders,
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating bottom navigation bar: icons only, active one in sky blue.
  // ---------------------------------------------------------------------------

  Widget _buildFloatingBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(29),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              _buildNavItem(0, Icons.home_rounded),
              _buildNavItem(1, Icons.grid_view_rounded),
              _buildNavItem(2, Icons.pie_chart_rounded),
              _buildNavItem(3, Icons.favorite_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final selected = _currentIndex == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => _select(index),
          borderRadius: BorderRadius.circular(29),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              scale: selected ? 1.12 : 1,
              child: Icon(
                icon,
                size: 24,
                color: selected ? kActiveBlue : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search trigger shown in the top bar.
// ---------------------------------------------------------------------------

class _SearchTrigger extends StatelessWidget {
  const _SearchTrigger({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 42,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search products, brands & more',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wishlist/cart icon button with a count badge, pinned to the top bar.
class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.countKey,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final String countKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        key: ValueKey<String>(countKey),
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(icon),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable category bar with the storefront quick destinations.
// ---------------------------------------------------------------------------

class _CategoriesBar extends StatelessWidget {
  const _CategoriesBar({
    required this.categories,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelected,
    required this.onOpenAllCategories,
    required this.onOpenVendors,
    required this.onOpenOrders,
  });

  final List<Category> categories;
  final Category? selected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Category?> onSelected;
  final VoidCallback onOpenAllCategories;
  final VoidCallback onOpenVendors;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              const Icon(
                Icons.category_outlined,
                size: 16,
                color: AppColors.primaryDeep,
              ),
              const SizedBox(width: 6),
              Text(
                'Categories',
                style: AppTextStyles.caption(context).copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _QuickLink(
                icon: Icons.grid_view_outlined,
                tooltip: 'All Categories',
                onPressed: onOpenAllCategories,
              ),
              _QuickLink(
                icon: Icons.store_mall_directory_outlined,
                tooltip: 'Vendors',
                onPressed: onOpenVendors,
              ),
              _QuickLink(
                icon: Icons.receipt_long_outlined,
                tooltip: 'Orders',
                onPressed: onOpenOrders,
              ),
              IconButton(
                tooltip:
                    expanded ? 'Collapse categories' : 'Expand categories',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleExpanded,
              ),
            ],
          ),
        ),
        if (expanded)
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = index == 0 ? null : categories[index - 1];
                final active = category == null
                    ? selected == null
                    : selected?.id == category.id;
                return _CategoryPill(
                  label: category?.name ?? 'All',
                  active: active,
                  onTap: () => onSelected(category),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Compact icon shortcut to a storefront section.
class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: Icon(icon, color: AppColors.primaryDeep),
    );
  }
}

/// Pill-style category chip; highlights when active.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? kActiveBlue : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.brandGradient),
            color: active ? null : AppColors.surface,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account sheet widgets.
// ---------------------------------------------------------------------------

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({this.user});

  final UserRecord? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.display ?? 'Guest';
    final detail = user?.email ?? user?.phone ?? 'Not signed in';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: MvColors.gradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: color),
      ),
      onTap: onTap,
    );
  }
}
