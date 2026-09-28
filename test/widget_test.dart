import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mvec_mobile/features/marketplace/presentation/Screens/home_screen.dart';
import 'package:mvec_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MvecAdminApp()));

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ADMIN CONTROL'), findsOneWidget);
    expect(find.text('Email or telephone'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  testWidgets('product detail screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    final productName = find.text('Wireless Over-Ear Headphones').first;
    await tester.tap(productName);
    await tester.pumpAndSettle();

    expect(find.text('In Stock (42)'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.byTooltip('Open wishlist'), findsOneWidget);
    expect(find.byTooltip('Open cart'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Wireless Over-Ear Headphones'), findsWidgets);
  });

  testWidgets('home cart and wishlist badges show current item counts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    Badge badgeFor(String countKey) =>
        tester.widget<Badge>(find.byKey(ValueKey<String>(countKey)));

    expect(badgeFor('home-cart-count').isLabelVisible, isFalse);
    expect(badgeFor('home-wishlist-count').isLabelVisible, isFalse);

    final homeList = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(homeList, const Offset(0, -600));
    await tester.pumpAndSettle();

    final productName = find.text('Wireless Over-Ear Headphones').first;
    await tester.tap(productName);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Search products, brands & more'), findsOneWidget);
    expect(find.byTooltip('Cart'), findsOneWidget);
    expect(find.byTooltip('Wishlist'), findsOneWidget);
    final cartBadge = badgeFor('home-cart-count');
    expect(cartBadge.isLabelVisible, isTrue);
    expect((cartBadge.label as Text).data, '1');

    await tester.ensureVisible(productName);
    await tester.tap(productName);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    final wishlistBadge = badgeFor('home-wishlist-count');
    expect(wishlistBadge.isLabelVisible, isTrue);
    expect((wishlistBadge.label as Text).data, '1');

    await tester.tap(find.byTooltip('Wishlist'));
    await tester.pumpAndSettle();
    expect(find.text('My Wishlist'), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart'), findsOneWidget);
  });

  testWidgets('product cards add directly to cart and wishlist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    final homeList = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(homeList, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add to wishlist'), findsWidgets);
    expect(find.byTooltip('Add to cart'), findsWidgets);

    await tester.tap(find.byTooltip('Add to cart').first);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Badge>(find.byKey(const ValueKey('home-cart-count'))).label
              as Text)
          .data,
      '1',
    );

    await tester.tap(find.byTooltip('Add to wishlist').first);
    await tester.pumpAndSettle();
    expect(
      (tester
                  .widget<Badge>(
                    find.byKey(const ValueKey('home-wishlist-count')),
                  )
                  .label
              as Text)
          .data,
      '1',
    );
    expect(find.text('Add to Cart'), findsNothing);
  });

  testWidgets('adding a wishlisted product to cart removes it from wishlist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    final homeList = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(homeList, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to wishlist').first);
    await tester.pumpAndSettle();
    expect(
      (tester
                  .widget<Badge>(
                    find.byKey(const ValueKey('home-wishlist-count')),
                  )
                  .label
              as Text)
          .data,
      '1',
    );

    await tester.tap(find.byTooltip('Add to cart').first);
    await tester.pumpAndSettle();

    final wishlistBadge = tester.widget<Badge>(
      find.byKey(const ValueKey('home-wishlist-count')),
    );
    expect(wishlistBadge.isLabelVisible, isFalse);
    expect(
      (tester.widget<Badge>(find.byKey(const ValueKey('home-cart-count'))).label
              as Text)
          .data,
      '1',
    );

    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart'), findsOneWidget);
    expect(find.textContaining('Wireless Over-Ear Headphones'), findsOneWidget);
  });

  testWidgets('product wishlist can be moved into the cart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    final homeList = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(homeList, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wireless Over-Ear Headphones').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('My Wishlist'), findsOneWidget);
    expect(find.text('Wireless Over-Ear Headphones'), findsWidgets);

    await tester.tap(find.text('Move to Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your wishlist is empty'), findsOneWidget);

    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart'), findsOneWidget);
    expect(find.text('Wireless Over-Ear Headphones'), findsOneWidget);
  });

  testWidgets('tapping a top menu item switches the body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    final menu = find.byType(ListView).first;
    await tester.drag(menu, const Offset(-800, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('#MV-20415'), findsOneWidget);
  });

  testWidgets('selecting a category shows products in that category', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MvecApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Categories').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronics'));
    await tester.pumpAndSettle();

    expect(find.text('Shop'), findsAtLeastNWidgets(2));
    expect(find.text('1 products'), findsOneWidget);
    expect(find.text('Gaming Mechanical Keyboard'), findsOneWidget);
    expect(find.text('Linen Summer Dress'), findsNothing);
  });
}
