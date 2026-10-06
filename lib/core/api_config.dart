import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API base URL used by the app.
///
/// Resolution order (highest priority first):
/// 1. `--dart-define=API_BASE_URL=...` — wins so a build can target a
///    different host (e.g. `10.0.2.2` for the Android emulator) without
///    editing `.env`.
/// 2. `API_BASE_URL` from `.env` (loaded at startup via `dotenv.load()`).
/// 3. the deployed MVEC backend.
String get kApiBaseUrl {
  // A compile-time define must beat the checked-in `.env`, otherwise
  // `flutter run --dart-define=API_BASE_URL=...` is silently ignored.
  const defined = String.fromEnvironment('API_BASE_URL');
  if (defined.trim().isNotEmpty) return defined.trim();

  try {
    final envUrl = dotenv.maybeGet('API_BASE_URL');
    if (envUrl != null && envUrl.trim().isNotEmpty) return envUrl.trim();
  } catch (_) {
    // dotenv is not loaded (e.g. tests) — fall back to the default below.
  }
  // Fallback for when neither the define nor `.env` is available (e.g. tests,
  // or a build that forgot to ship the env file).
  return 'http://157.173.119.15:3000/api';
}
