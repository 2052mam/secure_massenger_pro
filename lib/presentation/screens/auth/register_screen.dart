import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/device_service.dart';
import '../../../data/services/terms_service.dart';
import '../../widgets/chat/terms_dialog.dart';
import 'phone_verification_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialMobileNumber});

  /// Prefilled when the login screen redirected an unregistered number here.
  final String? initialMobileNumber;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    final mobile = widget.initialMobileNumber?.trim();
    if (mobile != null && mobile.isNotEmpty) _mobileCtrl.text = mobile;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _showTerms() async {
    final accepted = await TermsDialog.show(context, requireAccept: true);
    if (accepted == true && mounted) setState(() => _termsAccepted = true);
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      setState(() => _error = 'برای ثبت‌نام باید قوانین را بخوانید و بپذیرید');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceInfo = await DeviceService.getDeviceInfo();
      final username = _usernameCtrl.text.trim().toLowerCase();
      final res = await ApiService().post('/auth/register', {
        'email': _emailCtrl.text.trim().toLowerCase(),
        'mobile_number': _mobileCtrl.text.trim(),
        'password': _passwordCtrl.text,
        if (username.isNotEmpty) 'username': username,
        'display_name': _displayNameCtrl.text.trim(),
        'device_info': deviceInfo,
        'terms_accepted': true,
        'terms_version': TermsService.currentVersion,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneVerificationScreen(
            verificationId: res['verification_id'] as String,
            mobileNumber:
                res['mobile_number'] as String? ?? _mobileCtrl.text.trim(),
            flow: PhoneVerificationFlow.registration,
            deliveryChannel: res['delivery_channel'] as String? ?? 'sms',
            resendAfterSeconds:
                (res['resend_after_seconds'] as num?)?.toInt() ?? 300,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'خطا در ارتباط با سرور');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت‌نام', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2AABEE),
                          primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add_rounded, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ایجاد حساب جدید',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'برای ادامه، یک کد تأیید با پیامک ارسال می‌شود. Google Authenticator اختیاری است.',
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'نام نمایشی',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: primary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'حداقل ۲ کاراکتر'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'آیدی (اختیاری)',
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: primary),
                    helperText:
                        'فقط حروف کوچک، عدد و _ — بعداً هم می‌توانید بسازید',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (t.length < 3 || t.length > 30) return '۳ تا ۳۰ کاراکتر';
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(t)) {
                      return 'فرمت نامعتبر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.email_outlined, color: primary),
                  ),
                  validator: (v) {
                    if (v == null || !v.contains('@')) return 'ایمیل نامعتبر';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'شماره موبایل',
                    hintText: '09149141414',
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: Icon(Icons.phone_outlined, color: primary),
                    helperText: 'با کد کشور وارد کنید؛ مثال: 09121234567',
                  ),
                  validator: (v) {
                    final compact = (v ?? '').replaceAll(
                      RegExp(r'[\s()\-.]'),
                      '',
                    );
                    if (!RegExp(r'^(?:\+|00)?[0-9]{8,15}$').hasMatch(compact)) {
                      return 'شماره موبایل نامعتبر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'حداقل ۸ کاراکتر' : null,
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: _showTerms,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _termsAccepted
                            ? const Color(0xFF4CAF50)
                            : theme.dividerColor.withValues(alpha: 0.5),
                        width: _termsAccepted ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: _termsAccepted
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _termsAccepted
                              ? Icons.check_circle_rounded
                              : Icons.rule_rounded,
                          color: _termsAccepted ? const Color(0xFF4CAF50) : primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'قوانین و مقررات',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                'برای مطالعه و پذیرش لمس کنید (اسکرول تا انتها)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_termsAccepted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'پذیرفته شد',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ثبت‌نام و ادامه',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
