import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/widgets/primary_textfield.dart';

import '../../controllers/notifications.dart';
import '../../utils/toas_message.dart';
import '../../widgets/round_button.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _processAndSendNotifications(
    String title,
    String message,
  ) async {
    try {
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<String> fcmTokens = [];
      for (var doc in userSnapshot.docs) {
        String? token = doc.get('fcmToken');
        if (token != null && token.isNotEmpty) {
          fcmTokens.add(token);
        }
      }

      for (String token in fcmTokens) {
        await LocalNotificationService.sendNotificationUsingApi(
          title: title,
          body: message,
          token: token,
          data: {},
        );
      }

      MessageToast.showToast(msg: 'Notifications sent successfully!');
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to send notifications: $e');
    }
  }

  Future<void> _sendNotifications() async {
    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      MessageToast.showToast(msg: 'Please enter both title and message.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    _processAndSendNotifications(title, message);

    setState(() {
      _isSending = false;
    });

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  SizedBox(height: 32.h),
                  _buildFormCard(),
                  SizedBox(height: 24.h),

                  RoundButton(
                    onPressed: _sendNotifications,
                    text: 'Send Broadcast',
                    isLoading: _isSending,
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: Container(
        margin: EdgeInsets.only(left: 12.w),
        child: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: const Color(0xFF1A1D26),
              size: 18.sp,
            ),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      title: Text(
        'Send Notification',
        style: GoogleFonts.inter(
          color: const Color(0xFF1A1D26),
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFF3B82F6),
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Notification Details',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D26),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          PrimaryTextField(
            headerText: 'Title',
            hintText: 'Enter notification title',
            controller: _titleController,
          ),
          SizedBox(height: 20.h),
          PrimaryTextField(
            headerText: 'Message',
            hintText: 'Enter notification message',
            maxLines: 5,
            controller: _messageController,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDDEAFB).withAlpha(150),
            const Color(0xFFEFF6FF).withAlpha(150),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF3B82F6).withAlpha(40),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withAlpha(30),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: const Color(0xFF3B82F6),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1D26),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'This notification will be sent to all registered users instantly.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
