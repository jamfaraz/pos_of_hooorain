import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;
  final bool isFullWidth;

  const AdminCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor = kPrimaryColor,
    this.textColor = Colors.black,
    this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,

          borderRadius: BorderRadius.circular(5.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 13.h),
          child: isFullWidth ? _buildRowLayout() : _buildColumnLayout(),
        ),
      ),
    );
  }

  Widget _buildColumnLayout() {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 30.sp),
        SizedBox(height: 12.h),
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        SizedBox(height: 8.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRowLayout() {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24.sp),
        SizedBox(width: 8.w),
        Text(title, style: GoogleFonts.inter(fontSize: 14.sp)),
        const Spacer(),
        if (value.isNotEmpty)
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: textColor,
              fontSize: 13.sp,
            ),
          ),
      ],
    );
  }
}
