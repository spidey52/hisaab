import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_action_button.dart';
import 'auth_controller.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = Get.find<AuthController>();
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    final challenge = _controller.challenge.value;
    _remaining = challenge?.resendAfterSeconds ?? 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remaining == 0) return;
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!RegExp(r'^\d{4,10}$').hasMatch(_code.text.trim())) {
      _controller.errorMessage.value = 'Enter the verification code.';
      return;
    }
    await _controller.verifyOtp(_code.text.trim());
  }

  Future<void> _resend() async {
    final phone = _controller.challenge.value?.phoneE164;
    if (phone == null) return;
    final sent = await _controller.requestOtp(phone);
    if (!sent || !mounted) return;
    final challenge = _controller.challenge.value;
    setState(() {
      _remaining = challenge?.resendAfterSeconds ?? 60;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final challenge = _controller.challenge.value;
    if (challenge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back<void>());
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.greenSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.mark_chat_read_outlined,
                    size: 32,
                    color: colors.greenDark,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Enter verification code',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to ${challenge.maskedPhone}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, fontSize: 16),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: displayStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 22),
              Obx(
                () => AsyncActionButton(
                  busy: _controller.busy.value,
                  onPressed: _verify,
                  label: 'Verify and continue',
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _remaining == 0 ? _resend : null,
                child: Text(
                  _remaining > 0
                      ? 'Send again in $_remaining seconds'
                      : 'Send code again',
                ),
              ),
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Change mobile number'),
              ),
              Obx(
                () => _controller.errorMessage.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _controller.errorMessage.value!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.red),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
