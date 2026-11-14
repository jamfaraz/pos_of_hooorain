import 'package:flutter/material.dart';

import 'app_loader.dart';

abstract final class LoadingPlaceholder {
  static Widget fromColors({
    required Color baseColor,
    required Color highlightColor,
    required Widget child,
  }) => const AppLoader(label: 'Loading...');
}
