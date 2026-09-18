import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/device_service.dart';
import '../../providers/auth_provider.dart';
import 'support_contact_sheet.dart';
import 'two_factor_screen.dart';

enum PhoneVerificationFlow { registration, login }

/// Telegram-style code entry for both registration and phone-first login.
/// The code is intentionally never kept in persistent storage.
///
/// Round 2 additions:
///  * Point 1 — a live countdown showing when the code can be sent again.
///  * Point 3 — when the account already has a live session the server sends
///    the code inside the app, so the copy changes and an explicit
///    "send by SMS instead" action is offered.
///  * Point 6 — a "contact support" entry point for people stuck here.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String mobileNumber;
  final PhoneVerificationFlow flow;

  /// 'in_app' when the code was delivered to another signed-in device,
  /// 'sms' otherwise. Comes straight from the request-code response.
  final String deliveryChannel;

  /// Seconds until the code may be resent. The server's resend cooldown.
  final int resendAfterSeconds;

  const PhoneVerificationScreen({
    super.key,
    required this.verificationId,
    required this.mobileNumber,
    required this.flow,
    this.deliveryChannel = 'sms',
    this.resendAfterSeconds = 300,
  });

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _codeCtrl = TextEditingController();
  late String _verificationId;
  late String _channel;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _message;

  /// Point 1: countdown until a new code can be requested.
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _channel = widget.deliveryChannel;
    _startCountdown(widget.resendAfterSeconds);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    final total = seconds <= 0 ? 0 : seconds;
    setState(() => _secondsLeft = total);
    if (total == 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  /// mm:ss, always two digits, so the label never jumps around.
  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _inApp => _channel == 'in_app';

  Future<void> _verify() async {
    if (_loading) return;
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'کد ۶ رقمی را وارد کنید');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await ApiService().post('/auth/verify-phone', {
        'verification_id': _verificationId,
        'code': code,
        'device_info': await DeviceService.getDeviceInfo(),
      });
      if (!mounted) return;
      if (response['require_2fa'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TwoFactorScreen(
              verificationId: response['verification_id'] as String,
            ),
          ),
        );
        return;
      }
      await _saveSession(response);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'خطا در تأیید کد');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
    await ref.read(authNotifierProvider.notifier).setLoggedIn(
          user,
          response['access_token'] as String,
          response['refresh_token'] as String? ?? '',
        );
  }

  /// [forceSms] maps to Point 3's "send by SMS instead" escape hatch.
  Future<void> _resend({bool forceSms = false}) async {
    if (_loading || _resending) return;
    if (_secondsLeft > 0 && !forceSms) return;
    setState(() {
      _resending = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await ApiService().post('/auth/resend-phone-code', {
        'verification_id': _verificationId,
        if (forceSms) 'force_sms': true,
      });
      if (!mounted) return;
      final channel = response['delivery_channel'] as String? ?? 'sms';
      setState(() {
        _verificationId =
            response['verification_id'] as String? ?? _verificationId;
        _channel = channel;
        _codeCtrl.clear();
        _message = channel == 'in_app'
            ? 'کد جدید به دستگاه دیگری که با آن وارد شده‌اید ارسال شد.'
            : 'کد جدید پیامک شد.';
      });
      _startCountdown(
        (response['resend_after_seconds'] as num?)?.toInt() ?? widget.resendAfterSeconds,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      // A 429 carries the remaining wait; reflect it in the timer.
      final retryAfter = error.details['retry_after_seconds'];
      if (retryAfter is num) _startCountdown(retryAfter.toInt());
    } catch (_) {
      if (mounted) setState(() => _error = 'ارسال دوباره کد ممکن نیست');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _contactSupport() async {
    final sent = await showSupportContactSheet(
      context,
      mobileNumber: widget.mobileNumber,
      initialTopic: 'code_not_received',
    );
    if (sent && mounted) {
      setState(() => _message =
          'پیام شما برای پشتیبانی ثبت شد. به‌زودی با شما تماس گرفته می‌شود.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final registering = widget.flow == PhoneVerificationFlow.registration;
    final waiting = _secondsLeft > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(registering ? 'تأیید شماره موبایل' : 'ورود با شماره موبایل'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _inApp ? Icons.forum_outlined : Icons.sms_outlined,
                  size: 68,
                  color: Colors.blue,
                ),
                const SizedBox(height: 18),
                Text(
                  registering
                      ? 'شماره خود را تأیید کنید'
                      : 'کد ورود را وارد کنید',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _inApp
                      ? 'کد ۶ رقمی را در برنامه‌ی دستگاه دیگری که با شماره '
                          '${widget.mobileNumber} وارد شده‌اید فرستادیم.'
                      : 'کد ۶ رقمی به ${widget.mobileNumber} پیامک شد.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_inApp) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'چون قبلاً با این شماره وارد شده‌اید، کد به‌جای '
                            'پیامک داخل برنامه ارسال شد.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                TextField(
                  controller: _codeCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 10),
                  decoration: InputDecoration(
                    labelText: _inApp ? 'کد ارسال‌شده در برنامه' : 'کد پیامک',
                    counterText: '',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(registering ? 'تأیید و ورود' : 'ورود'),
                  ),
                ),
                const SizedBox(height: 10),
                // Point 1: the countdown replaces the resend button until the
                // server is willing to send another code.
                if (waiting)
                  Row(
                    key: const ValueKey('resend-countdown'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'ارسال دوباره کد تا $_countdownLabel دیگر',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    key: const ValueKey('resend-button'),
                    onPressed: _resending ? null : () => _resend(),
                    icon: _resending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('کد را دریافت نکردید؟ ارسال دوباره'),
                  ),
                // Point 3: always allow falling back to SMS.
                if (_inApp)
                  TextButton.icon(
                    key: const ValueKey('force-sms-button'),
                    onPressed: _resending ? null : () => _resend(forceSms: true),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('ارسال کد با پیامک'),
                  ),
                const Divider(height: 28),
                // Point 6.
                TextButton.icon(
                  key: const ValueKey('contact-support-button'),
                  onPressed: _loading ? null : _contactSupport,
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('کد به دستم نمی‌رسد — تماس با پشتیبانی'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
