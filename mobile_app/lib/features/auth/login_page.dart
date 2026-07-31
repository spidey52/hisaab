import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/async_action_button.dart';
import '../../shared/widgets/brand_mark.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = Get.find<AuthController>();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    final value = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (value.length == 10) return '+91$value';
    return '+$value';
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final sent = await _controller.requestOtp(_normalizedPhone());
    if (sent) Get.toNamed(AppRoutes.otp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 62),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome to Hisaab',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use your mobile number to securely open your ledger.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 34),
                TextFormField(
                  controller: _phone,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.length == 10 ||
                        (digits.length >= 11 && digits.length <= 15)) {
                      return null;
                    }
                    return 'Enter a valid mobile number';
                  },
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We will send a one-time verification code.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Obx(
                  () => AsyncActionButton(
                    busy: _controller.busy.value,
                    onPressed: _continue,
                    label: 'Send verification code',
                  ),
                ),
                Obx(
                  () => _controller.errorMessage.value == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _controller.errorMessage.value!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
