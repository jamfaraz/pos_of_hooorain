import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/auth/login_screen.dart';
import '../services/admin_access_service.dart';
import '../widgets/app_loader.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final access = Get.find<AdminAccessService>();
    return Obx(() {
      if (access.isChecking.value) return const _AuthLoadingScreen();
      if (access.error.value.isNotEmpty) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not verify admin access.'),
                TextButton(onPressed: access.retry, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      if (!access.isAdmin.value) return const LoginScreen();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.currentRoute == '/') Get.offAllNamed('/dashboard');
      });
      return const _AuthLoadingScreen();
    });
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: const Padding(
            padding: EdgeInsets.all(28),
            child: AppLoader(label: 'Checking your account...'),
          ),
        ),
      ),
    );
  }
}
