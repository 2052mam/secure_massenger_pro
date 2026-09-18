import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'two_factor_setup_screen.dart';

/// Settings entry point for the explicitly optional Google Authenticator layer.
class TwoFactorSecurityScreen extends ConsumerStatefulWidget {
  const TwoFactorSecurityScreen({super.key});

  @override
  ConsumerState<TwoFactorSecurityScreen> createState() =>
      _TwoFactorSecurityScreenState();
}

class _TwoFactorSecurityScreenState
    extends ConsumerState<TwoFactorSecurityScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Point 4: two-step verification is a primary-device-only setting. We ask
  /// the server up front so the buttons can be disabled with an explanation,
  /// instead of letting the user type a code and then get a 403.
  bool _onPrimaryDevice = true;
  bool _checkedPrimary = false;

  @override
  void initState() {
    super.initState();
    _checkPrimaryDevice();
  }

  Future<void> _checkPrimaryDevice() async {
    try {
      final response = await ApiService().get('/security/alerts',
          query: {'limit': '1'});
      if (!mounted) return;
      setState(() {
        _onPrimaryDevice = response['is_primary_device'] == true;
        _checkedPrimary = true;
      });
    } catch (_) {
      // Leave the controls enabled; the server still enforces the rule.
      if (mounted) setState(() => _checkedPrimary = true);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSetup() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().post('/auth/2fa/setup', {});
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TwoFactorSetupScreen(
            totpSecret: response['totp_secret'] as String,
            totpUri: response['totp_uri'] as String,
            warning: response['warning'] as String? ?? '',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'فعال‌سازی تأیید دو مرحله‌ای ممکن نیست');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disable() async {
    if (_loading) return;
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'کد ۶ رقمی Google Authenticator را وارد کنید');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().post('/auth/2fa/disable', {'code': code});
      final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      ref.read(authNotifierProvider.notifier).setUser(user);
      if (!mounted) return;
      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأیید دو مرحله‌ای غیرفعال شد')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'غیرفعال‌سازی ممکن نیست');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(authNotifierProvider).valueOrNull?.isTwoFactorEnabled ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('تأیید دو مرحله‌ای')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                enabled ? Icons.verified_user_outlined : Icons.security_outlined,
                size: 68,
                color: enabled ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                enabled ? 'Google Authenticator فعال است' : 'Google Authenticator اختیاری است',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                enabled
                    ? 'پس از پیامک ورود، کد Google Authenticator نیز درخواست می‌شود.'
                    : 'ورود معمول فقط با کد پیامک انجام می‌شود. برای امنیت بیشتر می‌توانید یک مرحله دوم اضافه کنید.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (_checkedPrimary && !_onPrimaryDevice) ...[
                const SizedBox(height: 20),
                Container(
                  key: const ValueKey('primary-device-notice'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تغییر تأیید دو مرحله‌ای فقط از دستگاه اصلی حساب '
                          'امکان‌پذیر است. از همان دستگاه وارد شوید یا در بخش '
                          '«دستگاه‌ها» دستگاه اصلی را منتقل کنید.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              if (!enabled)
                ElevatedButton.icon(
                  onPressed: (_loading || !_onPrimaryDevice) ? null : _startSetup,
                  icon: const Icon(Icons.add_moderator_outlined),
                  label: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('فعال‌سازی Google Authenticator'),
                )
              else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'کد ۶ رقمی برای غیرفعال‌سازی', counterText: ''),
                  onSubmitted: (_) => _disable(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_loading || !_onPrimaryDevice) ? null : _disable,
                  icon: const Icon(Icons.remove_moderator_outlined, color: Colors.red),
                  label: const Text('غیرفعال‌سازی', style: TextStyle(color: Colors.red)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
