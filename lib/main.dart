import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'models/user.dart' show AuthSession;
import 'providers/auth_provider.dart';
import 'features/marketplace/presentation/providers/commerce_provider.dart';
import 'features/marketplace/presentation/providers/home_provider.dart';

/// Single entrypoint for the MVEC app.
///
/// The app is one project with two audiences behind the same auth gate:
/// the super admin lands on the control-center dashboard (`/admin`) and every
/// other role lands on the marketplace home feed (`/home`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // Resolved before the first frame so the light/dark preference is already
  // applied on launch and the app never flashes the wrong theme.
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const MvecApp(),
    ),
  );
}

class MvecApp extends ConsumerWidget {
  const MvecApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final routerConfig = ref.watch(routerProvider);
    // The storefront providers sit above the router so pages pushed on top of
    // the marketplace (search, categories, vendors, orders) inherit them too.
    // Both come from Riverpod so tests can substitute a fake data source, and
    // both are lazy, so nothing is fetched until the marketplace is opened.
    return p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider(
          create: (_) => ref.watch(homeProviderProvider)..loadHomeFeed(),
        ),
        p.ChangeNotifierProvider(
          create: (_) => ref.watch(commerceProviderProvider),
        ),
      ],
      child: _CartSessionSync(
        child: MaterialApp.router(
          title: 'MVEC',
          debugShowCheckedModeBanner: false,
          theme: lightAppTheme,
          darkTheme: darkAppTheme,
          themeMode: themeMode,
          routerConfig: routerConfig,
        ),
      ),
    );
  }
}

/// Keeps the server cart in step with the signed-in session.
///
/// The cart lives on the backend, so it is fetched as soon as a session exists
/// and dropped locally when the session ends. Without this the cart stayed
/// empty for the whole session until some other call happened to write to it.
class _CartSessionSync extends ConsumerWidget {
  const _CartSessionSync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthSession?>(authControllerProvider.select((s) => s.session), (
      previous,
      next,
    ) {
      if (previous?.token == next?.token) return;

      final cart = p.Provider.of<CommerceProvider>(context, listen: false);
      if (next == null) {
        cart.resetLocalCart();
      } else {
        cart.loadCart();
      }
    });
    return child;
  }
}
