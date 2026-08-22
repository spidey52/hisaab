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
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64, showName: true),
                  const SizedBox(height: 12),
                  Text(
                    'Simple records. Clear balances.',
                    style: TextStyle(color: colors.muted),
                  ),
                  const SizedBox(height: 34),
                  if (_controller.errorMessage.value == null)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.muted,
                      ),
                    )
                  else ...[
                    Text(
                      _controller.errorMessage.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.red),
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
