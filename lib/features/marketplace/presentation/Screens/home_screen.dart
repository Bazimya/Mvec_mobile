import 'package:cached_network_image/cached_network_image.dart';
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
    this.onViewDeals,
    this.onCategoryTap,
  });

  /// Switches the top navigation to the Shop tab (All Categories).
  final VoidCallback? onBrowseAll;
  final VoidCallback? onViewDeals;
  final ValueChanged<Category>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    if (provider.isLoading && provider.feed.banners.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = provider.categories;
    final visibleCategories =
        categories.length > 8 ? categories.sublist(0, 8) : categories;
    final featuredIds =
        provider.featuredProducts.map((product) => product.id).toSet();
    final popularProducts = <Product>[
      ...provider.featuredProducts,
      ...provider.products.where(
        (product) => !featuredIds.contains(product.id),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.loadHomeFeed,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (provider.isDemo) const _DemoNotice(),
                _MarketplaceHero(
                  products: popularProducts,
                  onShopNow: onBrowseAll,
                  onViewDeals: onViewDeals,
                ),
                if (provider.banners.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  BannerCarousel(banners: provider.banners),
                ],
                const SizedBox(height: 20),
                if (visibleCategories.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                    eyebrow: 'SHOP BY CATEGORY',
                    title: 'Find what you need',
                    actionLabel: 'View all →',
                    onAction: onBrowseAll,
                  ),
                  const SizedBox(height: 12),
                  CategoryGrid(
                    categories: visibleCategories,
                    onCategoryTap: _onCategoryTap,
                  ),
                  const SizedBox(height: 20),
                ],
                if (popularProducts.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                    eyebrow: 'TRENDING NOW',
                    title: 'Popular products',
                    actionLabel: 'View all products →',
                    onAction: onBrowseAll,
                  ),
                  const SizedBox(height: 12),
                  _ProductRow(products: popularProducts),
                  const SizedBox(height: 20),
                ],
                for (final category in visibleCategories)
                  if (provider.products.any(
                    (product) =>
                        product.categoryId == category.id ||
                        product.categoryName == category.name,
                  )) ...<Widget>[
                    _SectionHeader(
                      eyebrow: category.name.toUpperCase(),
                      title: category.name,
                      actionLabel: 'More ${category.name} →',
                      onAction: () => _onCategoryTap(category),
                    ),
                    const SizedBox(height: 12),
                    _ProductRow(
                      products:
                          provider.products
                              .where(
                                (product) =>
                                    product.categoryId == category.id ||
                                    product.categoryName == category.name,
                              )
                              .take(4)
                              .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                if (provider.recommendedProducts.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: 'Recommended For You'),
                  const SizedBox(height: 12),
                  _ProductRow(products: provider.recommendedProducts),
                  const SizedBox(height: 20),
                ],
                if (onViewDeals != null) ...<Widget>[
                  _DealsBanner(onTap: onViewDeals!),
                  const SizedBox(height: 20),
                ],
                if (provider.vendors.isNotEmpty) ...<Widget>[
                  _SectionHeader(
                    eyebrow: 'TOP STORES',
                    title: 'Trusted vendors',
                  ),
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

/// Marketplace hero, matched to the web `Home.jsx` / `styles.css`
/// `.hero-modern` block: a full-width bordered surface whose right side carries
/// a soft gradient panel (`.hero-modern:after`) with floating product cards
/// (`.hero-product-card`) over a blurred glow (`.visual-glow`). Copy, button
/// styles, the gradient/outline pair and the trust row follow the web exactly.
class _MarketplaceHero extends StatelessWidget {
  const _MarketplaceHero({
    required this.products,
    required this.onShopNow,
    required this.onViewDeals,
  });

  final List<Product> products;
  final VoidCallback? onShopNow;
  final VoidCallback? onViewDeals;

  @override
  Widget build(BuildContext context) {
    // The web floats the first six products in the visual stage.
    final heroProducts = products.take(6).toList();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.mv.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 640;
          final copy = _HeroCopy(
            onShopNow: onShopNow,
            onViewDeals: onViewDeals,
            isWide: isWide,
          );
          final stage = _HeroProductStage(products: heroProducts);

          // Narrow screens stack the copy above the stage, like the web's
          // `.hero-modern` at <=900px.
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, stage],
            );
          }
          // Side-by-side columns. Neither column is height-constrained, so
          // each sizes to its own content and nothing can overflow; the outer
          // gradient fills whatever the taller column ends up being.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 9, child: copy),
              Expanded(flex: 11, child: stage),
            ],
          );
        },
      ),
    );
  }
}

/// Left column of the hero: eyebrow, animated title, tagline, buttons, trust row.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.onShopNow,
    required this.onViewDeals,
    required this.isWide,
  });

  final VoidCallback? onShopNow;
  final VoidCallback? onViewDeals;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final mv = context.mv;
    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 24, isWide ? 8 : 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'MVEC MARKETPLACE',
            style: AppTextStyles.caption(context).copyWith(
              color: mv.accentDeep,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          // The web renders the title as three inline spans
          // (<span>Shop.</span> <span>Sell.</span> <em>Grow together.</em>).
          // They stay separate so each keeps its own weight/colour, but wrap
          // onto as few lines as the width allows to keep the hero compact.
          Wrap(
            spacing: 6,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _heroWord(context, 'Shop.', isWide),
              _heroWord(context, 'Sell.', isWide),
              Text(
                'Grow together.',
                style: AppTextStyles.headline(context).copyWith(
                  fontSize: isWide ? 34 : 27,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  color: mv.accentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Products from trusted sellers across Rwanda.',
            style: AppTextStyles.bodySecondary(
              context,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: onShopNow,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Shop now'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
              OutlinedButton(onPressed: onViewDeals, child: const Text('Start selling')),
            ],
          ),
          const SizedBox(height: 16),
          // Web trust row: "✓ Verified sellers · ✓ Secure checkout · ✓ Local delivery".
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: const [
              _TrustItem(label: 'Verified sellers'),
              _TrustItem(label: 'Secure checkout'),
              _TrustItem(label: 'Local delivery'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroWord(BuildContext context, String word, bool isWide) => Text(
    word,
    style: AppTextStyles.headline(context).copyWith(
      fontSize: isWide ? 34 : 27,
      height: 1.02,
      fontWeight: FontWeight.w800,
    ),
  );
}

/// A single "✓ label" trust marker, mirroring the web `.trust-row span`.
class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_circle, size: 14, color: context.mv.accentDeep),
      const SizedBox(width: 5),
      Text(
        label,
        style: AppTextStyles.caption(context).copyWith(fontSize: 11),
      ),
    ],
  );
}

/// Right column of the hero: the gradient panel with floating product cards.
class _HeroProductStage extends StatelessWidget {
  const _HeroProductStage({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      // `.hero-modern:after` gradient panel.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F9FD), Color(0xFFC9F0FB)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 420;
          // Two staggered columns of floating cards, echoing the web's
          // absolutely-positioned hero-product-0..5. Capped at two per column
          // so the stage stays a sane height on a phone.
          final columns = <List<Product>>[
            <Product>[],
            <Product>[],
          ];
          final capped = products.take(4).toList();
          for (var i = 0; i < capped.length; i++) {
            columns[i % 2].add(capped[i]);
          }
          return Stack(
            children: [
              // `.visual-glow` blurred circle.
              Positioned(
                right: isWide ? 40 : 12,
                top: isWide ? 24 : 8,
                child: Container(
                  width: isWide ? 190 : 120,
                  height: isWide ? 190 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 22 : 14,
                  vertical: isWide ? 24 : 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < columns.length; col++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: col == 1 ? 10 : 0),
                          child: Column(
                            children: [
                              for (var i = 0; i < columns[col].length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 10,
                                    top: i.isOdd ? (isWide ? 18 : 10) : 0,
                                  ),
                                  child: _HeroProductCard(
                                    product: columns[col][i],
                                    imageHeight: isWide ? 108 : 84,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single floating product card, mirroring `.hero-product-card`.
class _HeroProductCard extends StatelessWidget {
  const _HeroProductCard({required this.product, required this.imageHeight});
  final Product product;

  /// Fixed image height keeps the card (and therefore the hero) a predictable
  /// size, so a long product name or a narrow phone can never overflow it.
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<HomeProvider>().addRecentlyViewed(product);
        openProductDetails(context, product);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF18586F).withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: product.imageUrl.isEmpty
                    ? Container(color: context.mv.soft)
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, _) =>
                            Container(color: context.mv.soft),
                        errorWidget: (context, _, _) =>
                            Container(color: context.mv.soft),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(context).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.mv.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '\$${product.price.toStringAsFixed(0)}',
              style: AppTextStyles.caption(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.mv.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealsBanner extends StatelessWidget {
  const _DealsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE9F9FD), Color(0xFFC6EDF8)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MVEC DEAL DAYS',
                  style: AppTextStyles.caption(context).copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'More products.\nLess searching.',
                  style: AppTextStyles.sectionTitle(
                    context,
                  ).copyWith(fontSize: 20, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Explore deals from verified sellers.',
                  style: AppTextStyles.bodySecondary(context),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('Shop deals'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.local_offer_outlined,
            size: 58,
            color: AppColors.primaryDeep.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
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
              style: TextStyle(color: warning, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title row mirroring the web `.section-heading`: an optional
/// uppercase eyebrow above the title, with a trailing "View all →" action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: AppTextStyles.caption(context).copyWith(
                    color: context.mv.accentDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle(context),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: TextStyle(
                color: context.mv.accentDeep,
                fontWeight: FontWeight.w800,
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
