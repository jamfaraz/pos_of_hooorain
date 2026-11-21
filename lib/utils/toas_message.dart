import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

class _ToastPalette {
  const _ToastPalette({
    required this.surface,
    required this.border,
    required this.heading,
    required this.body,
    required this.accent,
  });

  final Color surface;
  final Color border;
  final Color heading;
  final Color body;
  final Color accent;
}

class MessageToast {
  static const _success = _ToastPalette(
    surface: Color(0xFFF3FAF6),
    border: Color(0xFFBFE3D0),
    heading: Color(0xFF064E3B),
    body: Color(0xFF2F6B57),
    accent: Color(0xFF047857),
  );

  static const _error = _ToastPalette(
    surface: Color(0xFFFDF4F4),
    border: Color(0xFFF3C6C6),
    heading: Color(0xFF7F1D1D),
    body: Color(0xFF9B4A4A),
    accent: Color(0xFFB91C1C),
  );

  static const _warning = _ToastPalette(
    surface: Color(0xFFFFF8EC),
    border: Color(0xFFF1D9A8),
    heading: Color(0xFF78350F),
    body: Color(0xFF92602A),
    accent: Color(0xFFB45309),
  );

  static const _info = _ToastPalette(
    surface: Color(0xFFF3F7FE),
    border: Color(0xFFC7D7F5),
    heading: Color(0xFF1E3A8A),
    body: Color(0xFF4A5F94),
    accent: Color(0xFF1D4ED8),
  );

  static _ToastPalette _paletteFor(ToastificationType type) => switch (type) {
    ToastificationType.success => _success,
    ToastificationType.error => _error,
    ToastificationType.warning => _warning,
    _ => _info,
  };

  static void showSuccess({
    required String msg,
    String? title,
    Widget? action,
  }) => showToast(
    msg: msg,
    title: title,
    action: action,
    type: ToastificationType.success,
  );

  static void showError({required String msg, String? title, Widget? action}) =>
      showToast(
        msg: msg,
        title: title,
        action: action,
        type: ToastificationType.error,
      );

  static void showInfo({required String msg, String? title, Widget? action}) =>
      showToast(
        msg: msg,
        title: title,
        action: action,
        type: ToastificationType.info,
      );

  static void showWarning({
    required String msg,
    String? title,
    Widget? action,
  }) => showToast(
    msg: msg,
    title: title,
    action: action,
    type: ToastificationType.warning,
  );

  static void showToast({
    required String msg,
    String? title,
    Widget? action,
    ToastificationType type = ToastificationType.info,
  }) {
    final p = _paletteFor(type);
    toastification.show(
      type: type,
      style: ToastificationStyle.minimal,
      alignment: Alignment.topCenter,
      autoCloseDuration: Duration(seconds: action == null ? 4 : 6),
      title: Text(
        title ?? msg,
        style: GoogleFonts.interTight(
          color: p.heading,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
      description: title == null && action == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    msg,
                    style: GoogleFonts.interTight(
                      color: p.body,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
      primaryColor: p.accent,
      backgroundColor: p.surface,
      foregroundColor: p.heading,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: p.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
      showProgressBar: false,
      closeOnClick: true,
    );
  }
}
