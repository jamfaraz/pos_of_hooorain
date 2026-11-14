import 'package:flutter/material.dart';

import '../../widgets/app_loader.dart';

class UserDetailLoading extends StatelessWidget {
  const UserDetailLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppLoader(label: 'Loading customer details...');
}
