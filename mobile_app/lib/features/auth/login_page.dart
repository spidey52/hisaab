import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/config/app_config.dart';
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
  final _serverUrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _serverUrl.text = _controller.customApiBaseUrl.value;
  }

  @override
  void dispose() {
    _phone.dispose();
    _serverUrl.dispose();
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
    final colors = context.colors;
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
                  child: BrandMark(size: 72),
                ),
                const SizedBox(height: 26),
                Text(
                  'Your khata,\nin your pocket',
                  style: displayStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: -0.8,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use your mobile number to securely open your ledger.',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Sign in with',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  final mode = _controller.serverMode.value;
                  return SegmentedButton<ServerMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ServerMode>(
                        value: ServerMode.cloud,
                        label: Text('Hisaab Cloud'),
                        icon: Icon(Icons.cloud_outlined, size: 18),
                      ),
                      ButtonSegment<ServerMode>(
                        value: ServerMode.selfHosted,
                        label: Text('Self-hosted'),
                        icon: Icon(Icons.dns_outlined, size: 18),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (value) {
                      _controller.selectServerMode(value.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
                Obx(() {
                  if (_controller.serverMode.value != ServerMode.selfHosted) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextFormField(
                      controller: _serverUrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.url],
                      autocorrect: false,
                      onChanged: _controller.updateCustomApiBaseUrl,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://hisaab.example.com',
                        helperText: 'Enter the full URL of your Hisaab server',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        if (_controller.serverMode.value !=
                            ServerMode.selfHosted) {
                          return null;
                        }
                        return AppConfig.selfHostedApiOriginError(value ?? '');
                      },
                    ),
                  );
                }),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phone,
                  autofocus: true,
                  maxLength: 10,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: colors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We will send a one-time verification code.',
                        style: TextStyle(color: colors.muted),
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
                            style: TextStyle(color: colors.red),
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
