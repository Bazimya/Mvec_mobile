import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/vendor_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/mv_icon.dart';

/// In-flight state for the seller-upgrade form.
class BecomeSellerState {
  const BecomeSellerState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

final becomeSellerProvider =
    NotifierProvider<BecomeSellerController, BecomeSellerState>(
      BecomeSellerController.new,
    );

class BecomeSellerController extends Notifier<BecomeSellerState> {
  @override
  BecomeSellerState build() => const BecomeSellerState();

  /// Posts to `/vendors/become-seller`. Returns true on success, after which the
  /// caller sends the account to its new seller dashboard.
  Future<bool> submit({
    required String businessName,
    required String phone,
    required String email,
    String? description,
  }) async {
    state = const BecomeSellerState(busy: true);
    try {
      await ref
          .read(vendorServiceProvider)
          .becomeSeller(
            businessName: businessName,
            phone: phone,
            email: email,
            description: description,
          );
      // The account's role changed, so re-read it before navigating.
      await ref.read(authControllerProvider.notifier).refreshSession();
      state = const BecomeSellerState();
      return true;
    } catch (e) {
      state = BecomeSellerState(error: friendlyError(e));
      return false;
    }
  }
}

/// Become a Seller — the account upgrade form.
///
/// Posts to `POST /vendors/become-seller`, the same route the web console uses,
/// then sends the account to the seller dashboard it has just unlocked.
///
/// The web console files this page under `/admin/become-seller`; it is also
/// mounted at `/become-seller` so a buyer can reach it from their own account
/// sheet, which is where the action actually applies.
class BecomeSellerScreen extends ConsumerStatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  ConsumerState<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends ConsumerState<BecomeSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in account, exactly as the web form does.
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _phone.text = user.phone ?? '';
      _email.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _businessName.dispose();
    _phone.dispose();
    _email.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(becomeSellerProvider.notifier)
        .submit(
          businessName: _businessName.text,
          phone: _phone.text,
          email: _email.text,
          description: _description.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/vendor');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(becomeSellerProvider);
    final user = ref.watch(currentUserProvider);
    final alreadySeller = (user?.role ?? '').toLowerCase() == 'vendor';

    return Scaffold(
      appBar: AppBar(title: const Text('Become a Seller')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHead(
                eyebrow: 'SELLER MODE',
                title: 'Sell on MVEC',
                subtitle:
                    'Open a seller account to list products, fulfil orders and receive payouts.',
              ),
              if (alreadySeller) ...[
                const InfoBox(
                  'This account is already a seller. Your store is on the seller '
                  'dashboard.',
                ),
                const SizedBox(height: 16),
              ],
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: MvColors.errorText,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _businessName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  hintText: 'The store name buyers will see',
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Enter your business name'
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+250 7xx xxx xxx',
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Enter a phone number MVEC can reach you on'
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator:
                    (v) =>
                        (v == null || !v.contains('@'))
                            ? 'Enter a valid email address'
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What do you sell?',
                  hintText: 'Optional — a short description of your catalogue',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: state.busy ? 'Setting up…' : 'Open seller account',
                icon: 'shop',
                onPressed: state.busy || alreadySeller ? null : _submit,
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MvIcon('bell', size: 15, color: Theme.of(context).hintColor),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'MVEC verifies new sellers before they can list products. '
                      'You will be able to upload your verification documents '
                      'from the seller dashboard.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
