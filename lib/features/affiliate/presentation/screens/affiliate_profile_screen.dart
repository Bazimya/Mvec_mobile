import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../widgets/common.dart';
import '../../data/models/affiliate_profile.dart';
import '../providers/affiliate_providers.dart';
import '../widgets/affiliate_widgets.dart';

/// Affiliate identity editor + verification status. Mirrors the frontend
/// affiliate account page: a profile grid (form | status) with the referral
/// code and verification journey on the right.
class AffiliateProfileScreen extends ConsumerStatefulWidget {
  const AffiliateProfileScreen({super.key});

  @override
  ConsumerState<AffiliateProfileScreen> createState() =>
      _AffiliateProfileScreenState();
}

class _AffiliateProfileScreenState
    extends ConsumerState<AffiliateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final k in [
      'displayName',
      'phone',
      'website',
      'country',
      'bio',
      'accountName',
      'accountNumber',
    ])
      k: TextEditingController(),
  };
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _init(AffiliateProfile p) {
    if (_initialized) return;
    _initialized = true;
    _load(p);
  }

  void _load(AffiliateProfile p) {
    void set(String k, String? v) {
      _c[k]!.text = v ?? '';
    }

    set('displayName', p.displayName);
    set('phone', p.phone);
    set('website', p.website);
    set('country', p.country);
    set('bio', p.bio);
    set('accountName', p.payoutAccountName);
    set('accountNumber', p.payoutAccountNumber);
  }

  Future<void> _save(AffiliateProfile current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(affiliateServiceProvider)
          .updateProfile(
            current.copyWith(
              displayName: _c['displayName']!.text.trim(),
              phone: _c['phone']!.text.trim(),
              website: _c['website']!.text.trim(),
              country: _c['country']!.text.trim(),
              bio: _c['bio']!.text.trim(),
              payoutAccountName: _c['accountName']!.text.trim(),
              payoutAccountNumber: _c['accountNumber']!.text.trim(),
            ),
          );
      if (!mounted) return;
      showMvSnack(context, 'Profile saved', success: true);
      ref.invalidate(affiliateProfileProvider);
    } catch (e) {
      if (!mounted) return;
      showMvSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitVerification() async {
    final identityUrl = TextEditingController();
    final businessUrl = TextEditingController();
    final documents = await showDialog<List<Map<String, String>>>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Submit verification documents'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paste secure URLs for documents uploaded to your document provider.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: identityUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Identity document URL',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: businessUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Business document URL',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final entries = <Map<String, String>>[];
                  final identity = identityUrl.text.trim();
                  final business = businessUrl.text.trim();
                  if (_isHttpUrl(identity)) {
                    entries.add({'type': 'IDENTITY', 'url': identity});
                  }
                  if (_isHttpUrl(business)) {
                    entries.add({'type': 'BUSINESS', 'url': business});
                  }
                  if (entries.isEmpty) return;
                  Navigator.pop(dialogContext, entries);
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
    identityUrl.dispose();
    businessUrl.dispose();
    if (documents == null || !mounted) return;
    try {
      await ref.read(affiliateServiceProvider).submitVerification(documents);
      if (!mounted) return;
      ref.invalidate(affiliateVerificationProvider);
      ref.invalidate(affiliateProfileProvider);
      showMvSnack(context, 'Documents submitted for review', success: true);
    } catch (e) {
      if (!mounted) return;
      showMvSnack(context, friendlyError(e));
    }
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(affiliateProfileProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHead(
          eyebrow: 'Account',
          title: 'Affiliate Profile',
          subtitle: 'Your public publisher profile and payout details.',
        ),
        async.when(
          loading: () => const LoadingState(),
          error:
              (e, _) => ErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(affiliateProfileProvider),
              ),
          data: (profile) {
            _init(profile);
            return LayoutBuilder(
              builder: (context, c) {
                final form = _buildForm(profile);
                final aside = _buildAside(profile);
                if (c.maxWidth > 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: form),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: aside),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [form, const SizedBox(height: 16), aside],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildForm(AffiliateProfile profile) {
    return Form(
      key: _formKey,
      child: DataCard(
        title: 'Publisher details',
        subtitle: 'Shown alongside the campaigns you share.',
        child: Column(
          children: [
            _field(
              'displayName',
              'Display name',
              'e.g. Rwanda Deals',
              textInputAction: TextInputAction.next,
            ),
            _field(
              'phone',
              'Phone number',
              'e.g. 0788 123 456',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            _field(
              'website',
              'Website / social link',
              'https://…',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            _field(
              'country',
              'Country',
              'e.g. Rwanda',
              textInputAction: TextInputAction.next,
            ),
            _field('bio', 'Bio', 'Tell people what you promote', maxLines: 3),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: _saving ? 'Saving…' : 'Save changes',
                    icon: 'check',
                    expanded: true,
                    onPressed: _saving ? null : () => _save(profile),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    String hint, {
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _c[key]!,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) {
          if (key == 'displayName' && (v == null || v.trim().isEmpty)) {
            return 'Enter a display name';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAside(AffiliateProfile profile) {
    final verificationAsync = ref.watch(affiliateVerificationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataCard(
          title: 'Verification',
          subtitle: profile.verificationStatus ?? 'UNVERIFIED',
          trailing: StatusChip(
            profile.verificationStatus ?? 'UNVERIFIED',
            overrideColor: profile.isVerified ? MvColors.successText : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              verificationAsync.when(
                loading: () => const LoadingState(),
                error:
                    (_, __) => ProcessTimeline(
                      steps:
                          AffiliateVerification(
                            status: profile.verificationStatus ?? 'UNVERIFIED',
                          ).steps,
                    ),
                data:
                    (verification) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProcessTimeline(steps: verification.steps),
                        if (verification.notes?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              verification.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                        for (final document in verification.documents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              document,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
              ),
              if (!profile.isVerified &&
                  profile.verificationStatus != 'PENDING') ...[
                const SizedBox(height: 8),
                OutlineMvButton(
                  label: 'Submit documents',
                  icon: 'shield',
                  onPressed: _submitVerification,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        DataCard(
          title: 'Referral code',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Code', profile.code),
              _kv('Commission rate', '${profile.commissionRate ?? 8}%'),
              _kv('Joined', shortDate(profile.joinedAt)),
              _kv('Status', profile.status ?? 'ACTIVE'),
              const SizedBox(height: 10),
              ReferralCodeCard(profile: profile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
