import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/admin_access_service.dart';
import '../widgets/app_loader.dart';

class AdminRouteGuard extends StatelessWidget {
  const AdminRouteGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final access = Get.find<AdminAccessService>();
    return Obx(() {
      if (access.isChecking.value) return _loadingScreen();
      if (access.error.value.isNotEmpty) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not verify admin access.'),
                const SizedBox(height: 8),
                TextButton(onPressed: access.retry, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      if (!access.isAdmin.value) {
        if (Get.currentRoute != '/login') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Get.currentRoute != '/login') Get.offAllNamed('/login');
          });
        }
        return _loadingScreen();
      }
      return child;
    });
  }

  Widget _loadingScreen() {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(32),
        child: AppLoader(label: 'Verifying access...'),
      ),
    );
  }
}
