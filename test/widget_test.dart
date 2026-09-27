import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mvec_mobile/features/marketplace/presentation/Screens/home_screen.dart';
import 'package:mvec_mobile/main.dart';

void main() {
  testWidgets('selecting a product opens its details', (
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

    await tester.tap(find.byIcon(Icons.favorite_border).first);
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
}
