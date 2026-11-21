import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/constants.dart';

class ErrorRetryWidget extends StatelessWidget {
  final String? mainMessage;
  final String errorMessage;
  final VoidCallback onRetry;
  final IconData? icon;
  final String? buttonText;

  const ErrorRetryWidget({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.buttonText = 'Retry',
    this.mainMessage = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.redAccent),
            SizedBox(height: 16.h),
            Text(
              mainMessage ?? '',
              style: GoogleFonts.interTight(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                fontSize: 14.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(888.r),
                ),
                backgroundColor: kPrimaryColor,
                padding: EdgeInsets.symmetric(horizontal: 44.w, vertical: 9.h),
              ),
              onPressed: onRetry,
              child: Text(
                buttonText!,
                style: GoogleFonts.interTight(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
