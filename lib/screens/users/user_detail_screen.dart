import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hoorain_pos/widgets/full_image.dart';
import '../../constants.dart';
import '../../widgets/backbutton.dart';
import 'user_detail_loading.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserDetailScreenState createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool isLoading = true;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load user data',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateProfileStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'profileStatus': status,
            'isVerified': status == 'verified',
          });

      setState(() {
        userData!['profileStatus'] = status;
        userData!['isVerified'] = status == 'verified';
      });

      Get.snackbar(
        'Success',
        'Profile status updated to ${status.toUpperCase()}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update status',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showStatusDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Update Profile Status',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: kblack,
              ),
            ),
            SizedBox(height: 24.h),
            _buildStatusOption(
              'Verified',
              'User is verified and can place COD orders',
              Icons.verified_user_rounded,
              Colors.green,
              'verified',
            ),
            SizedBox(height: 12.h),
            _buildStatusOption(
              'Not Verified',
              'User needs verification before COD',
              Icons.pending_rounded,
              Colors.orange,
              'notVerified',
            ),
            SizedBox(height: 12.h),
            _buildStatusOption(
              'Rejected',
              'User verification rejected',
              Icons.cancel_rounded,
              Colors.red,
              'rejected',
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String status,
  ) {
    final isSelected = userData!['profileStatus'] == status;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _updateProfileStatus(status);
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withAlpha(50),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: kblack,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24.sp),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        leading: const BackNavigatingButton(color: kblack),
        title: Text(
          'User Verification',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: kblack,
          ),
        ),
        backgroundColor: Colors.white,
        actions: [
          if (!isLoading && userData != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: kPrimaryColor),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                _fetchUserData();
              },
            ),
        ],
      ),
      body: isLoading
          ? UserDetailLoading()
          : userData == null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64.sp,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'User not found',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final fullName = userData!['fullName'] ?? 'N/A';
    final email = userData!['email'] ?? 'N/A';
    final phoneNumber = userData!['phoneNumber'] ?? 'N/A';
    final uniqueId = userData!['uniqueId'] ?? 'N/A';
    final profileStatus = userData!['profileStatus'] ?? 'notVerified';
    final isVerified = userData!['isVerified'] ?? false;
    final userImage = userData!['image'] ?? '';
    final locationImage = userData!['locationImage'] ?? '';
    final createdAt = userData!['createdAt'] as Timestamp?;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            _buildProfileHeader(fullName, userImage, profileStatus, isVerified),
            SizedBox(height: 16.h),

            // Location Image Card (Most Important for Verification)
            if (locationImage.isNotEmpty) ...[
              _buildSectionTitle(
                'Location Verification',
                Icons.location_on_rounded,
              ),
              SizedBox(height: 12.h),
              _buildLocationImageCard(locationImage),
              SizedBox(height: 16.h),
            ],

            // User Information Card
            _buildSectionTitle('User Information', Icons.person_rounded),
            SizedBox(height: 12.h),
            _buildUserInfoCard(
              fullName,
              email,
              phoneNumber,
              uniqueId,
              createdAt,
            ),
            SizedBox(height: 16.h),

            InkWell(
              onTap: _showStatusDialog,
              borderRadius: BorderRadius.circular(16.r),
              child: Container(
                padding: EdgeInsets.all(18.w),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Update Status',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    String fullName,
    String userImage,
    String profileStatus,
    bool isVerified,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (profileStatus) {
      case 'verified':
        statusColor = Colors.green;
        statusText = 'Verified';
        statusIcon = Icons.verified_user_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Not Verified';
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withAlpha(25),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(13.w),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Get.to(() => FullImageScreen(imageUrl: userImage));
            },

            child: Stack(
              children: [
                Container(
                  width: 122.w,
                  height: 122.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kPrimaryColor.withAlpha(178),
                        kPrimaryColor.withAlpha(76),
                      ],
                    ),

                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withAlpha(76),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                    image: userImage.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(userImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: userImage.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          size: 50.sp,
                          color: Colors.white,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 3,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withAlpha(127),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(statusIcon, color: Colors.white, size: 20.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 9.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: GoogleFonts.inter(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: kblack,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: statusColor.withAlpha(76)),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationImageCard(String locationImage) {
    return InkWell(
      onTap: () => Get.to(() => FullImageScreen(imageUrl: locationImage)),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        height: 250.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Image.network(
                locationImage,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return LoadingPlaceholder.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64.sp,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 12.h,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(127),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(178), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20.r),
                  ),
                ),
                child: Text(
                  'Tap to view full image',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(
    String fullName,
    String email,
    String phoneNumber,
    String uniqueId,
    Timestamp? createdAt,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          _buildInfoRow(Icons.badge_rounded, 'Full Name', fullName),
          _buildDivider(),
          _buildInfoRow(Icons.email_rounded, 'Email', email),
          _buildDivider(),
          _buildInfoRow(Icons.phone_rounded, 'Phone Number', phoneNumber),
          _buildDivider(),
          _buildInfoRow(Icons.fingerprint_rounded, 'Unique ID', uniqueId),
          if (createdAt != null) ...[
            _buildDivider(),
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Joined',
              DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: kPrimaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 20.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: kblack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade200, height: 1, thickness: 1);
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryColor, kPrimaryColor.withAlpha(178)],
            ),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: Colors.white, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: kblack,
          ),
        ),
      ],
    );
  }
}
