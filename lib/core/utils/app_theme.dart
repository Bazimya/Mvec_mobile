import 'package:flutter/material.dart';

import '../theme.dart';

/// Storefront palette.
///
/// These are the same sky-blue design tokens the control center uses, re-exported
/// under the storefront names so both halves of the app can never drift apart.
/// Source of truth: [MvColors] in `core/theme.dart`.
class AppColors {
  AppColors._();

  /// `--blue` — the sky blue the app is built around.
  static const Color primary = MvColors.primary;
  static const Color primaryDark = MvColors.primaryDark;
  static const Color primaryDeep = MvColors.primaryDeep;
  static const Color primaryLight = MvColors.accentLight;

  /// Brand gradient, same as `--gradient` in the web app:
  /// `#9ae2fb 0%, #55c9f2 45%, #25addb 100%`.
  static const List<Color> brandGradient = <Color>[
    MvColors.accentLight,
    MvColors.primary,
    MvColors.primaryDark,
  ];

  static const Color secondary = Color(0xFFF0A629); // star rating amber
  static const Color accent = Color(0xFF168D67); // price-drop green
  static const Color soft = MvColors.soft; // --soft

  static const Color background = MvColors.page; // --page
  static const Color surface = Colors.white; // --surface
  static const Color surfaceVariant = MvColors.surface2; // --surface-2
  static const Color textPrimary = MvColors.ink; // --text / --ink
  static const Color textSecondary = MvColors.muted; // --muted-text
  static const Color border = MvColors.border; // --border / --line

  static const Color error = MvColors.errorText; // status.danger
  static const Color warning = MvColors.warningText; // status.warning/pending
  static const Color success = MvColors.successText; // status.active
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle headline(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          );

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          );

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.textPrimary,
          );

  static TextStyle bodySecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.textSecondary,
          );

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
            color: AppColors.textSecondary,
          );

  static TextStyle price(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      );

  static TextStyle oldPrice(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
        color: AppColors.textSecondary,
        decoration: TextDecoration.lineThrough,
      );
}

class AppTheme {
  AppTheme._();

  /// The storefront shares the control center theme so the whole app renders
  /// from one sky-blue palette.
  static ThemeData get light => buildAppTheme(Brightness.light);

  static ThemeData get dark => buildAppTheme(Brightness.dark);
}
