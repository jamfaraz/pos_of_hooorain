import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class ChipWidget extends StatelessWidget {
  final String subcategory;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDesktop;

  const ChipWidget({
    super.key,
    required this.subcategory,
    required this.isSelected,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20.w : 16.w,
          vertical: isDesktop ? 8.h : 4.h,
        ),
        margin: EdgeInsets.only(right: isDesktop ? 12.w : 8.w),
        decoration: BoxDecoration(
          color: isSelected ? kGreenColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(isDesktop ? 10.r : 6.r),
          border: Border.all(
            color: isSelected ? kGreenColor : Colors.grey.shade300,
            width: isDesktop ? 1.5.w : 1.w,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: kGreenColor.withAlpha(isDesktop ? 80 : 55),
                blurRadius: isDesktop ? 8.r : 4.r,
                offset: Offset(0, isDesktop ? 3.h : 2.h),
              ),
          ],
        ),
        child: Center(
          child: Text(
            subcategory,
            style: GoogleFonts.interTight(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: isDesktop ? 15.sp : 13.sp,
              letterSpacing: isDesktop ? -0.2 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
