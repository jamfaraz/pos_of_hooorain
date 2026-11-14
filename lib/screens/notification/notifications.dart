import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:hoorain_pos/widgets/retry_widget.dart';
import 'package:timeago/timeago.dart' as timeAgo;

import '../../../../constants.dart';
import '../../../controllers/data_controller.dart';
import '../../../models/order_model.dart';
import 'package:hoorain_pos/widgets/app_loader.dart';
import '../../utils/toas_message.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  DataController dataController = Get.put(DataController());

  bool _isLoading = true; // Track loading state

  List<DocumentSnapshot> notifications = [];

  @override
  void initState() {
    super.initState();
    // Mark notifications as read when the user enters the screen
    dataController.markNotificationsAsRead();
    _fetchNotifications();
  }

  // --- Utility Methods ---

  Future<void> _fetchNotifications() async {
    final snapshot = await dataController
        // Note: Using .first here makes it a single fetch, not a stream listener.
        .getNotification(FirebaseAuth.instance.currentUser!.uid)
        .first;
    setState(() {
      notifications = snapshot.docs;
      _isLoading = false;
    });
  }

  // Corrected to check both 'Admin' and a fallback collection (assuming the second 'Admin' check was meant to be 'users')
  Future<Map<String, dynamic>> fetchUserDetails(String userId) async {
    // If the notification source is the current user (e.g., system admin action), use a fallback name/image
    if (userId == FirebaseAuth.instance.currentUser!.uid) {
      return {'fullName': 'System Update', 'image': ''};
    }

    try {
      // 1. Check in 'Admin' collection
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Admin') // Check Admin
          .doc(userId)
          .get();
      if (userSnapshot.exists) {
        return {
          'fullName': userSnapshot['fullName'] ?? 'Admin User',
          'image': userSnapshot['image'] ?? '',
        };
      }

      // 2. Check in a general 'users' collection as a fallback
      userSnapshot = await FirebaseFirestore.instance
          .collection('users') // Check general users
          .doc(userId)
          .get();
      if (userSnapshot.exists) {
        return {
          'fullName': userSnapshot['fullName'] ?? 'Unknown User',
          'image': userSnapshot['image'] ?? '',
        };
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching user details: ${e.toString()}");
    }
    // Final fallback
    return {'fullName': 'System Update', 'image': ''};
  }

  // Re-implemented fetcher for order details
  Future<OrderModel?> _fetchOrderDetails(String orderId) async {
    try {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      if (orderSnapshot.exists) {
        final orderData = orderSnapshot.data();
        if (orderData != null) {
          return OrderModel.fromMap(orderData, orderSnapshot.id);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching order details for $orderId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,

        actions: [
          IconButton(
            onPressed: () {
              _fetchNotifications();

              setState(() {
                _isLoading = true;
              });
            },
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoader(label: 'Loading notifications...')
          : notifications.isEmpty
          ? ErrorRetryWidget(
              errorMessage:
                  'All your updates, news, and status changes will appear here.',
              onRetry: () {
                setState(() {
                  _isLoading = true;
                });
                _fetchNotifications(); // Reload data
              },
              mainMessage: 'No Notifications Yet! 🔔',
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final data = notifications[index];
                DateTime date;
                try {
                  date = data.get('time').toDate();
                } catch (e) {
                  date = DateTime.now();
                }

                return FutureBuilder<Map<String, dynamic>>(
                  future: fetchUserDetails(data['currentUserId']),
                  builder: (context, userSnapshot) {
                    final userDetails =
                        userSnapshot.data ??
                        {'fullName': 'Unknown', 'image': ''};

                    return GestureDetector(
                      onTap: () async {
                        final String? firestoreOrderId = data['orderId'];

                        if (firestoreOrderId != null) {
                          // Handle Order Status Update Deep Link
                          OrderModel? order = await _fetchOrderDetails(
                            firestoreOrderId,
                          );

                          // 🚨 CRASH FIX: Check for null before navigating
                          if (order != null) {
                            Get.toNamed('/orders/detail', arguments: order);
                          } else {
                            MessageToast.showToast(
                              msg: 'Order details not found.',
                            );
                          }
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: 5.h,
                          horizontal: 12,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 15.h,
                        ),
                        decoration: BoxDecoration(
                          color: data['isRead'] == false
                              ? const Color(0xFFD6FFEB) // Highlight unread
                              : Colors.white, // Standard background
                          borderRadius: BorderRadius.circular(10.sp),

                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildProfileImage(
                              userDetails['image'],
                              userDetails['fullName'] ?? '',
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userDetails['fullName'],
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    data['message'],
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: 11.sp,
                                    ),
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              children: [
                                Text(
                                  timeAgo.format(date),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: const Color(0xFF2E5FFF),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildProfileImage(String imageUrl, String name) {
    // Check if it's a system message, use a default icon if so
    if (name.contains('System Update') || imageUrl.isEmpty) {
      return Container(
        width: 56.sp,
        height: 56.sp,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kPrimaryColor.withAlpha(25),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.notifications_active,
          size: 28.sp,
          color: kPrimaryColor,
        ),
      );
    }

    return Container(
      width: 56.sp,
      height: 56.sp,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => LoadingPlaceholder.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.grey[300]),
                ),
                errorWidget: (context, url, error) => _fallbackInitial(name),
              ),
            )
          : _fallbackInitial(name),
    );
  }

  Widget _fallbackInitial(String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
    );
  }
}
