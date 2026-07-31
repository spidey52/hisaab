import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand_mark.dart';
import '../auth/auth_controller.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthController _controller = Get.find<AuthController>();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 76),
                  const SizedBox(height: 22),
                  Text(
                    'Hisaab',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Simple records. Clear balances.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 30),
                  if (_controller.errorMessage.value == null)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  else ...[
                    Text(
                      _controller.errorMessage.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _controller.restoreSession,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
