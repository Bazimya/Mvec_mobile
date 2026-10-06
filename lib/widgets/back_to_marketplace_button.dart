import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent "back to the storefront" action for every role portal.
///
/// Each shell already offers "View marketplace" in its navigation drawer, but a
/// drawer is two taps away and hides the way out. The admin, vendor, supplier,
/// affiliate and delivery shells all embed this in their top bar so any page
/// can reach `/home` in one tap.
class BackToMarketplaceButton extends StatelessWidget {
  const BackToMarketplaceButton({super.key, this.iconOnly = false});

  /// Render just the storefront glyph, for top bars that are already crowded.
  final bool iconOnly;

  /// `/home` is targeted directly: `/` resolves through `roleHome()` and would
  /// bounce a signed-in role straight back into its own portal.
  void _goHome(BuildContext context) => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final button =
        iconOnly
            ? IconButton(
              key: const ValueKey<String>('back-to-marketplace'),
              onPressed: () => _goHome(context),
              icon: const Icon(Icons.storefront_outlined, size: 20),
              tooltip: 'Back to marketplace',
            )
            : TextButton.icon(
              key: const ValueKey<String>('back-to-marketplace'),
              onPressed: () => _goHome(context),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Marketplace'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
    return button;
  }
}