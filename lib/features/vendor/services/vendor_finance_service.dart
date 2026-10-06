import '../../../core/api_client.dart';
import '../models/vendor_finance.dart';

/// Contract for the vendor's money: summary metrics, the transaction ledger and
/// withdrawal requests.
///
/// [ApiVendorFinanceService] is the production implementation; tests substitute
/// their own double without touching a screen.
abstract class VendorFinanceService {
  /// The four headline balances plus the commission rate and the daily series.
  Future<VendorFinanceSummary> summary();

  /// The money ledger, newest first, optionally narrowed to one [kind].
  Future<List<LedgerEntry>> ledger({LedgerEntryKind? kind, int limit = 50});

  /// Withdrawal requests, newest first. Pending ones are excluded from the
  /// available balance, so this list is what the payout form validates against.
  Future<List<PayoutRequest>> payouts();

  /// Requests a withdrawal of [amount].
  ///
  /// Throws when [amount] exceeds the available balance, falls under the
  /// platform minimum, or the destination is missing for the chosen [method].
  Future<PayoutRequest> requestPayout({
    required num amount,
    required PayoutMethod method,
    required String destination,
    String? note,
  });
}

/// Minimum withdrawal the platform will process, in RWF.
const double kMinPayoutAmount = 50000;

/// The client-side payout rules, checked before the request is sent so an
/// overdraw or a missing destination fails immediately with a message the payout
/// form can show next to the field. The backend re-checks the balance to stay
/// authoritative under concurrency.
///
/// Free function rather than a method so the rules are testable without a
/// network or a live balance.
void validatePayoutRequest({
  required num amount,
  required PayoutMethod method,
  required String destination,
  required num available,
}) {
  if (destination.trim().isEmpty) {
    throw ApiException('Enter the ${method.label} to receive your payout.');
  }
  if (amount < kMinPayoutAmount) {
    throw ApiException(
      'The minimum payout is ${kMinPayoutAmount.toStringAsFixed(0)} RWF.',
    );
  }
  if (amount > available) {
    throw ApiException(
      'You can withdraw at most ${available.toStringAsFixed(0)} RWF right now.',
    );
  }
}

/// Talks to the platform's finance API.
class ApiVendorFinanceService implements VendorFinanceService {
  ApiVendorFinanceService(this._api);
  final ApiClient _api;

  @override
  Future<VendorFinanceSummary> summary() async {
    final res = await _api.get('/stores/mine/finance/summary');
    return VendorFinanceSummary.fromJson(singleJson(res, ['summary', 'finance', 'data']));
  }

  @override
  Future<List<LedgerEntry>> ledger({LedgerEntryKind? kind, int limit = 50}) async {
    final res = await _api.get('/stores/mine/finance/ledger', query: {
      'limit': limit,
      if (kind != null) 'kind': kind.slug,
    });
    return listJson(res, ['entries', 'ledger', 'data']).map(LedgerEntry.fromJson).toList();
  }

  @override
  Future<List<PayoutRequest>> payouts() async {
    final res = await _api.get('/stores/mine/finance/payouts', query: {'limit': 30});
    return listJson(res, ['payouts', 'withdrawals', 'data']).map(PayoutRequest.fromJson).toList();
  }

  /// Requests a withdrawal.
  ///
  /// Amount and destination are checked against [kMinPayoutAmount] and the
  /// live available balance before the request is sent, so an overdraw fails
  /// immediately with a message the payout form can show next to the field.
  /// The backend re-checks the balance to stay authoritative under concurrency.
  @override
  Future<PayoutRequest> requestPayout({
    required num amount,
    required PayoutMethod method,
    required String destination,
    String? note,
  }) async {
    validatePayoutRequest(
      amount: amount,
      method: method,
      destination: destination,
      available: (await summary()).availablePayout,
    );

    final res = await _api.post('/stores/mine/finance/payouts', body: {
      'amount': amount,
      'method': method.slug,
      'destination': destination.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return PayoutRequest.fromJson(singleJson(res, ['payout']));
  }
}
