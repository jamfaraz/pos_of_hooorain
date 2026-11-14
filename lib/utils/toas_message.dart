import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';


class MessageToast {
  static showToast({required String msg}) {
    Fluttertoast.showToast(
      msg: msg,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFF00BF63),
      textColor: Colors.white,
      fontSize: 13.sp,
    );
  }
}