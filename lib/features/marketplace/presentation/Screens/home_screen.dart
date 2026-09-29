import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils/app_theme.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/vendor_model.dart';
import '../providers/home_provider.dart';
import '../Widgets/banner_carousel.dart';
import '../Widgets/category_grid.dart';
import '../Widgets/product_card.dart';
import '../Widgets/vendor_card.dart';
import 'product_navigation.dart';

/// Marketplace home feed.
///
/// Renders the banner carousel, category grid, featured products,
/// recommended products, and featured vendors from [HomeProvider].
/// Search lives in the shell's top bar, so it is not repeated here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onBrowseAll,
    this.onCategoryTap,
  });

  /// Switches the top navigation to the Shop tab (All Categories).
  final VoidCallback? onBrowseAll;
  final ValueChanged<Category>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    if (provider.isLoading && provider.feed.banners.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = provider.categories;
    final visibleCategories = categories.length > 8
        ? categories.sublist(0, 8)
        : categories;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.loadHomeFeed,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (provider.isDemo) const _DemoNotice(),
                const SizedBox(height: 12),
                BannerCarousel(banners: provider.banners),
                const SizedBox(height: 20),
                if (visibleCategories.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                    title: 'All Categories',
                    actionLabel: 'See all',
                    onAction: onBrowseAll,
                  ),
                  const SizedBox(height: 12),
                  CategoryGrid(
                    categories: visibleCategories,
                    onCategoryTap: _onCategoryTap,
                  ),
                  const SizedBox(height: 20),
                ],
                if (provider.featuredProducts.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: 'Featured Products'),
                  const SizedBox(height: 12),
                  _ProductRow(products: provider.featuredProducts),
                  const SizedBox(height: 20),
                ],
                if (provider.recommendedProducts.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: 'Recommended For You'),
                  const SizedBox(height: 12),
                  _ProductRow(products: provider.recommendedProducts),
                  const SizedBox(height: 20),
                ],
                if (provider.vendors.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: 'Trusted Vendors'),
                  const SizedBox(height: 12),
                  _VendorRow(vendors: provider.vendors),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onCategoryTap(Category category) => onCategoryTap?.call(category);
}

/// Small notice shown when the feed is served from the mock service.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final warning = AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are previewing demo data. Live products will appear when '
              'the marketplace API is connected.',
              style: TextStyle(
                color: warning,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title row with an optional trailing action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle(context),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: TextStyle(
                color: context.mv.accentDeep,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// Horizontal scrolling list of products.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomeProvider>();
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () {
              provider.addRecentlyViewed(product);
              openProductDetails(context, product);
            },
          );
        },
      ),
    );
  }
}

/// Horizontal scrolling list of featured vendors.
class _VendorRow extends StatelessWidget {
  const _VendorRow({required this.vendors});

  final List<Vendor> vendors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final vendor = vendors[index];
          return VendorCard(
            vendor: vendor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening ${vendor.name} store')),
              );
            },
          );
        },
      ),
    );
  }
}
