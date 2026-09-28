// Smoke tests for the MVEC authentication flow (Login / Registration /
// Forgot password) and the routing + validation helpers behind it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mvec_mobile/main.dart';
import 'package:mvec_mobile/models/user.dart';
import 'package:mvec_mobile/providers/auth_provider.dart';
import 'package:mvec_mobile/screens/auth/auth_validation.dart';

void main() {
  // Keep widget tests offline and deterministic: never fetch fonts at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('validation helpers', () {
    test('email / phone validation', () {
      expect(validateEmailOrPhone(''), isNotNull);
      expect(validateEmailOrPhone('not-an-email'), isNotNull);
      expect(validateEmailOrPhone('72xxxxxx'), isNotNull);
      expect(validateEmailOrPhone('user@example.com'), isNull);
      expect(validateEmailOrPhone('+250791234567'), isNull);
      expect(validatePhone('abcd'), isNotNull);
      expect(validatePhone('+250 791 234 567'), isNull);
      expect(validateEmail(''), isNull);
      expect(validateEmail('bad'), isNotNull);
    });

    test('password validation', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('123'), isNotNull);
      expect(validatePassword('123456'), isNull);
      expect(validateConfirmPassword('123', '456'), isNotNull);
      expect(validateConfirmPassword('456', '456'), isNull);
    });

    test('full name and otp validation', () {
      expect(validateFullName('Narada'), isNotNull);
      expect(validateFullName('Narada Test'), isNull);
      expect(validateOtp('123'), isNotNull);
      expect(validateOtp('abcdef'), isNotNull);
      expect(validateOtp('123456'), isNull);
    });
  });

  group('role routing', () {
    test('super admin goes to control center', () {
      final admin = UserRecord(role: 'super_admin');
      expect(roleHome(admin), '/admin');
    });

    test('buyer, vendor, supplier and affiliate land on the home feed', () {
      for (final role in ['buyer', 'vendor', 'supplier', 'affiliate']) {
        expect(roleHome(UserRecord(role: role)), '/home', reason: role);
      }
    });
  });

  group('app boot', () {
    testWidgets('boots to the login screen', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email or telephone'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('empty login submit shows validation errors',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email or telephone.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('invalid email shows a validation error', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'bad@email');
      await tester.enterText(find.byType(TextFormField).last, 'password1');
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });
  });

  group('registration', () {
    Future<void> openRegister(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Create one'));
      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens from the login screen and shows four user types',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await openRegister(tester);

      expect(find.text('Create your account'), findsOneWidget);
      for (final role in ['Buyer', 'Vendor', 'Supplier', 'Affiliate']) {
        expect(find.text(role), findsOneWidget, reason: role);
      }
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Telephone'), findsOneWidget);
    });

    testWidgets('selecting a vendor shows the company field',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await openRegister(tester);

      expect(find.text('Company name'), findsNothing);

      await tester.tap(find.text('Vendor'));
      await tester.pumpAndSettle();

      expect(find.text('Company name'), findsOneWidget);
    });

    testWidgets('register validation catches missing and mismatched fields',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await openRegister(tester);

      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your telephone number.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);

      // Field order for a buyer: name, telephone, email, password, confirm.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(3), 'password1');
      await tester.enterText(fields.at(4), 'password2');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('opens from login and renders the request form',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('Email or telephone'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('validates the identity before sending', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MvecApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
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

      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email or telephone.'), findsOneWidget);
    });
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
