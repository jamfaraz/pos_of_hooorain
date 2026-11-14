import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/widgets/app_loader.dart';
import '../../constants.dart';
import '../../controllers/user_controller.dart';
import '../../widgets/backbutton.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UsersController controller = Get.put(UsersController());
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await controller.fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          leading: const BackNavigatingButton(color: kblack),
          title: Text(
            'All Users',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: kblack,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48.h),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(
                      12,
                    ), // Using alpha instead of opacity
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                isScrollable: true,
                indicatorColor: kPrimaryColor,
                indicatorWeight: 3,
                labelColor: kPrimaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
                tabs: const [
                  Tab(text: 'Active Users'),
                  Tab(text: 'Banned Users'),
                  Tab(text: 'Verified Users'),
                  Tab(text: 'Unverified Users'),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            SizedBox(height: 16.h),
            _buildSearchField(),
            SizedBox(height: 16.h),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const AppLoader(label: 'Loading customers...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return _buildErrorState();
                }

                var activeUsers = controller.activeUsers
                    .where(
                      (user) =>
                          user['fullName'].toLowerCase().contains(
                            searchQuery,
                          ) ||
                          user['phoneNumber'].toLowerCase().contains(
                            searchQuery,
                          ),
                    )
                    .toList();

                var bannedUsers = controller.bannedUsers
                    .where(
                      (user) =>
                          user['fullName'].toLowerCase().contains(
                            searchQuery,
                          ) ||
                          user['phoneNumber'].toLowerCase().contains(
                            searchQuery,
                          ),
                    )
                    .toList();

                var verifiedUsers = controller.verifiedUsers
                    .where(
                      (user) =>
                          user['fullName'].toLowerCase().contains(
                            searchQuery,
                          ) ||
                          user['phoneNumber'].toLowerCase().contains(
                            searchQuery,
                          ),
                    )
                    .toList();

                var unverifiedUsers = controller.unverifiedUsers
                    .where(
                      (user) =>
                          user['fullName'].toLowerCase().contains(
                            searchQuery,
                          ) ||
                          user['phoneNumber'].toLowerCase().contains(
                            searchQuery,
                          ),
                    )
                    .toList();

                return TabBarView(
                  children: [
                    _buildUserListWithRefresh(activeUsers),
                    _buildUserListWithRefresh(bannedUsers),
                    _buildUserListWithRefresh(verifiedUsers),
                    _buildUserListWithRefresh(unverifiedUsers),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withAlpha(
                20,
              ), // Using alpha instead of opacity
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(fontSize: 14.sp, color: kblack),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 14.sp,
            ),
            prefixIcon: Container(
              padding: EdgeInsets.all(12.w),
              child: Icon(Icons.search_rounded, color: kPrimaryColor, size: 24),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: kPrimaryColor, width: 2.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: kPrimaryColor,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 64.sp,
                    color: Colors.red.shade400,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Oops! Something went wrong',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: kblack,
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                ElevatedButton.icon(
                  onPressed: _onRefresh,
                  icon: Icon(Icons.refresh_rounded, size: 20.sp),
                  label: Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 14.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserListWithRefresh(List users) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: kGreenColor,
      backgroundColor: Colors.white,
      child: _buildUserList(users),
    );
  }

  Widget _buildUserList(List users) {
    if (users.isEmpty) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withAlpha(
                      25,
                    ), // Using alpha instead of opacity
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 64.sp,
                    color: kPrimaryColor,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'No users found',
                  style: GoogleFonts.inter(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: kblack,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  searchQuery.isNotEmpty
                      ? 'Try adjusting your search'
                      : 'No users available at the moment',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userId = user.id;
        final fullName = user['fullName'] ?? 'N/A';
        final phoneNumber = user['phoneNumber'] ?? 'N/A';
        final isBanned = user['isBanned'] ?? false;
        final isVerified = user['isVerified'] ?? false;
        final userImage = user['image'];

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withAlpha(
                    20,
                  ), // Using alpha instead of opacity
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(
                    10,
                  ), // Using alpha instead of opacity
                  blurRadius: 8,
                  offset: Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () {
                  Get.to(
                    () => UserDetailScreen(userId: userId),
                    transition: Transition.cupertino,
                    duration: const Duration(milliseconds: 400),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Hero(
                            tag: 'user_$userId',
                            child: Container(
                              width: 55.w,
                              height: 62.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    kPrimaryColor.withAlpha(
                                      178,
                                    ), // ~70% opacity
                                    kPrimaryColor.withAlpha(76), // ~30% opacity
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kPrimaryColor.withAlpha(
                                      76,
                                    ), // ~30% opacity
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                image: userImage != null && userImage != ''
                                    ? DecorationImage(
                                        image: NetworkImage(userImage),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: userImage == null || userImage == ''
                                  ? Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 32.sp,
                                    )
                                  : null,
                            ),
                          ),
                          // Status indicator (Banned/Verified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 18.w,
                              height: 18.h,
                              decoration: BoxDecoration(
                                color: isBanned
                                    ? Colors.red
                                    : (isVerified
                                          ? Colors.green
                                          : Colors.orange),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isBanned
                                                ? Colors.red
                                                : (isVerified
                                                      ? Colors.green
                                                      : Colors.orange))
                                            .withAlpha(127), // ~50% opacity
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isBanned
                                    ? Icons.block_rounded
                                    : (isVerified
                                          ? Icons.verified_rounded
                                          : Icons.pending_rounded),
                                color: Colors.white,
                                size: 10.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 11.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: kblack,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                if (isVerified)
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Colors.blue,
                                    size: 16.sp,
                                  ),
                              ],
                            ),
                            SizedBox(height: 5.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 9.w,
                                vertical: 5.h,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withAlpha(
                                  25,
                                ), // Using alpha instead of opacity
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 14.sp,
                                    color: kPrimaryColor,
                                  ),
                                  SizedBox(width: 5.w),
                                  Flexible(
                                    child: Text(
                                      phoneNumber,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        color: kPrimaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBanned
                                        ? Colors.red.withAlpha(25)
                                        : Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: isBanned
                                          ? Colors.red.withAlpha(100)
                                          : Colors.green.withAlpha(100),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isBanned ? 'Banned' : 'Active',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color: isBanned
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isVerified
                                        ? Colors.blue.withAlpha(25)
                                        : Colors.orange.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: isVerified
                                          ? Colors.blue.withAlpha(100)
                                          : Colors.orange.withAlpha(100),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isVerified ? 'Verified' : 'Unverified',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color: isVerified
                                          ? Colors.blue
                                          : Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              controller.toggleBanStatus(userId, isBanned),
                          borderRadius: BorderRadius.circular(12.r),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isBanned
                                    ? [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ]
                                    : [
                                        Colors.red.shade400,
                                        Colors.red.shade600,
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: (isBanned ? Colors.green : Colors.red)
                                      .withAlpha(102), // ~40% opacity
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 7.h,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isBanned
                                      ? Icons.check_circle_rounded
                                      : Icons.block_rounded,
                                  color: Colors.white,
                                  size: 15.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  isBanned ? 'Unban' : 'Ban',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../constants.dart';
// import '../../controllers/user_controller.dart';
// import '../../widgets/backbutton.dart';
// import 'user_detail_screen.dart';

// class UsersScreen extends StatefulWidget {
//   const UsersScreen({super.key});

//   @override
//   State<UsersScreen> createState() => _UsersScreenState();
// }

// class _UsersScreenState extends State<UsersScreen> {
//   final UsersController controller = Get.put(UsersController());
//   final TextEditingController _searchController = TextEditingController();
//   String searchQuery = '';

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       setState(() => searchQuery = _searchController.text.trim().toLowerCase());
//     });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   Future<void> _onRefresh() async => controller.fetchUsers();

//   List _filter(List source) {
//     if (searchQuery.isEmpty) return source;
//     return source.where((user) {
//       final name = (user['fullName'] ?? '').toString().toLowerCase();
//       final phone = (user['phoneNumber'] ?? '').toString().toLowerCase();
//       return name.contains(searchQuery) || phone.contains(searchQuery);
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 4,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: AppBar(
//           elevation: 0,
//           scrolledUnderElevation: 0,
//           backgroundColor: Colors.white,
//           leading: const BackNavigatingButton(color: kblack),
//           title: Text(
//             'Users',
//             style: GoogleFonts.inter(
//               fontSize: 18.sp,
//               fontWeight: FontWeight.w700,
//               color: kblack,
//             ),
//           ),
//           bottom: PreferredSize(
//             preferredSize: Size.fromHeight(49.h),
//             child: Column(
//               children: [
//                 TabBar(
//                   isScrollable: true,
//                   tabAlignment: TabAlignment.start,
//                   indicatorColor: kPrimaryColor,
//                   indicatorWeight: 2.5,
//                   indicatorSize: TabBarIndicatorSize.label,
//                   labelColor: kPrimaryColor,
//                   unselectedLabelColor: Colors.grey.shade600,
//                   dividerColor: Colors.transparent,
//                   labelStyle: GoogleFonts.inter(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13.sp,
//                   ),
//                   unselectedLabelStyle: GoogleFonts.inter(
//                     fontWeight: FontWeight.w500,
//                     fontSize: 13.sp,
//                   ),
//                   tabs: [
//                     Tab(child: Obx(() => Text('Active (${controller.activeUsers.length})'))),
//                     Tab(child: Obx(() => Text('Banned (${controller.bannedUsers.length})'))),
//                     Tab(child: Obx(() => Text('Verified (${controller.verifiedUsers.length})'))),
//                     Tab(child: Obx(() => Text('Unverified (${controller.unverifiedUsers.length})'))),
//                   ],
//                 ),
//                 Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
//               ],
//             ),
//           ),
//         ),
//         body: Column(
//           children: [
//             _buildSearchField(),
//             Expanded(
//               child: Obx(() {
//                 if (controller.isLoading.value) {
//                 }
//                 if (controller.errorMessage.isNotEmpty) {
//                   return _buildErrorState();
//                 }
//                 return TabBarView(
//                   children: [
//                     _buildUserListWithRefresh(_filter(controller.activeUsers)),
//                     _buildUserListWithRefresh(_filter(controller.bannedUsers)),
//                     _buildUserListWithRefresh(_filter(controller.verifiedUsers)),
//                     _buildUserListWithRefresh(_filter(controller.unverifiedUsers)),
//                   ],
//                 );
//               }),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchField() {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
//       child: TextField(
//         controller: _searchController,
//         style: GoogleFonts.inter(fontSize: 14.sp, color: kblack),
//         decoration: InputDecoration(
//           hintText: 'Search by name or phone',
//           hintStyle: GoogleFonts.inter(
//             color: Colors.grey.shade500,
//             fontSize: 14.sp,
//           ),
//           prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
//           suffixIcon: _searchController.text.isNotEmpty
//               ? IconButton(
//                   icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
//                   onPressed: _searchController.clear,
//                 )
//               : null,
//           filled: true,
//           fillColor: Colors.grey.shade100,
//           isDense: true,
//           contentPadding: EdgeInsets.symmetric(vertical: 14.h),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.r),
//             borderSide: BorderSide.none,
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.r),
//             borderSide: BorderSide(color: kPrimaryColor, width: 1.5),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return RefreshIndicator(
//       onRefresh: _onRefresh,
//       color: kPrimaryColor,
//       child: ListView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         children: [
//           SizedBox(height: 120.h),
//           Icon(Icons.error_outline_rounded, size: 48.sp, color: Colors.red.shade400),
//           SizedBox(height: 16.h),
//           Text(
//             'Something went wrong',
//             textAlign: TextAlign.center,
//             style: GoogleFonts.inter(
//               fontSize: 16.sp,
//               fontWeight: FontWeight.w700,
//               color: kblack,
//             ),
//           ),
//           SizedBox(height: 8.h),
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 32.w),
//             child: Text(
//               controller.errorMessage.value,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade600),
//             ),
//           ),
//           SizedBox(height: 20.h),
//           Center(
//             child: OutlinedButton.icon(
//               onPressed: _onRefresh,
//               icon: Icon(Icons.refresh_rounded, size: 18.sp),
//               label: const Text('Try again'),
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: kPrimaryColor,
//                 side: BorderSide(color: kPrimaryColor),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10.r),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserListWithRefresh(List users) {
//     return RefreshIndicator(
//       onRefresh: _onRefresh,
//       color: kPrimaryColor,
//       backgroundColor: Colors.white,
//       child: _buildUserList(users),
//     );
//   }

//   Widget _buildUserList(List users) {
//     if (users.isEmpty) {
//       return ListView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         children: [
//           SizedBox(height: 120.h),
//           Icon(Icons.people_outline_rounded, size: 52.sp, color: Colors.grey.shade400),
//           SizedBox(height: 12.h),
//           Text(
//             'No users found',
//             textAlign: TextAlign.center,
//             style: GoogleFonts.inter(
//               fontSize: 16.sp,
//               fontWeight: FontWeight.w600,
//               color: kblack,
//             ),
//           ),
//           SizedBox(height: 6.h),
//           Text(
//             searchQuery.isNotEmpty
//                 ? 'Try adjusting your search'
//                 : 'Nothing to show here yet',
//             textAlign: TextAlign.center,
//             style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade600),
//           ),
//         ],
//       );
//     }

//     return ListView.separated(
//       physics: const AlwaysScrollableScrollPhysics(),
//       padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
//       itemCount: users.length,
//       separatorBuilder: (_, __) => SizedBox(height: 10.h),
//       itemBuilder: (context, index) => _buildUserTile(users[index]),
//     );
//   }

//   Widget _buildUserTile(dynamic user) {
//     final userId = user.id;
//     final String fullName = (user['fullName'] ?? 'N/A').toString();
//     final String phoneNumber = (user['phoneNumber'] ?? 'N/A').toString();
//     final bool isBanned = user['isBanned'] ?? false;
//     final bool isVerified = user['isVerified'] ?? false;
//     final String userImage = (user['image'] ?? '').toString();
//     final hasImage = userImage.isNotEmpty;

//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(14.r),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14.r),
//         onTap: () => Get.to(() => UserDetailScreen(userId: userId)),
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(14.r),
//             border: Border.all(color: Colors.grey.shade200),
//           ),
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 24.r,
//                 backgroundColor: kPrimaryColor.withAlpha(25),
//                 backgroundImage: hasImage ? NetworkImage(userImage) : null,
//                 child: hasImage
//                     ? null
//                     : Text(
//                         fullName.trim().isNotEmpty
//                             ? fullName.trim()[0].toUpperCase()
//                             : '?',
//                         style: GoogleFonts.inter(
//                           fontSize: 16.sp,
//                           fontWeight: FontWeight.w700,
//                           color: kPrimaryColor,
//                         ),
//                       ),
//               ),
//               SizedBox(width: 12.w),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Flexible(
//                           child: Text(
//                             fullName,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: GoogleFonts.inter(
//                               fontSize: 14.sp,
//                               fontWeight: FontWeight.w600,
//                               color: kblack,
//                             ),
//                           ),
//                         ),
//                         if (isVerified) ...[
//                           SizedBox(width: 4.w),
//                           Icon(Icons.verified_rounded, size: 15.sp, color: Colors.blue),
//                         ],
//                       ],
//                     ),
//                     SizedBox(height: 2.h),
//                     Text(
//                       phoneNumber,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: GoogleFonts.inter(
//                         fontSize: 12.sp,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                     SizedBox(height: 8.h),
//                     Wrap(
//                       spacing: 6.w,
//                       runSpacing: 4.h,
//                       children: [
//                         _statusChip(
//                           isBanned ? 'Banned' : 'Active',
//                           isBanned ? Colors.red : Colors.green,
//                         ),
//                         _statusChip(
//                           isVerified ? 'Verified' : 'Unverified',
//                           isVerified ? Colors.blue : Colors.orange,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               PopupMenuButton<String>(
//                 icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12.r),
//                 ),
//                 onSelected: (value) {
//                   if (value == 'view') {
//                     Get.to(() => UserDetailScreen(userId: userId));
//                   } else if (value == 'ban') {
//                     _confirmBanToggle(userId, fullName, isBanned);
//                   }
//                 },
//                 itemBuilder: (_) => [
//                   PopupMenuItem(
//                     value: 'view',
//                     child: Text('View details', style: GoogleFonts.inter(fontSize: 13.sp)),
//                   ),
//                   PopupMenuItem(
//                     value: 'ban',
//                     child: Text(
//                       isBanned ? 'Unban user' : 'Ban user',
//                       style: GoogleFonts.inter(
//                         fontSize: 13.sp,
//                         color: isBanned ? Colors.green.shade700 : Colors.red.shade600,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _statusChip(String label, Color color) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
//       decoration: BoxDecoration(
//         color: color.withAlpha(25),
//         borderRadius: BorderRadius.circular(20.r),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6.w,
//             height: 6.w,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//           ),
//           SizedBox(width: 5.w),
//           Text(
//             label,
//             style: GoogleFonts.inter(
//               fontSize: 11.sp,
//               fontWeight: FontWeight.w600,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _confirmBanToggle(dynamic userId, String name, bool isBanned) {
//     Get.dialog(
//       AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
//         title: Text(
//           isBanned ? 'Unban user?' : 'Ban user?',
//           style: GoogleFonts.inter(fontSize: 17.sp, fontWeight: FontWeight.w700),
//         ),
//         content: Text(
//           isBanned
//               ? '$name will regain access to the app.'
//               : '$name will no longer be able to use the app.',
//           style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade700),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Get.back(),
//             child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
//           ),
//           TextButton(
//             onPressed: () {
//               Get.back();
//               controller.toggleBanStatus(userId, isBanned);
//             },
//             child: Text(
//               isBanned ? 'Unban' : 'Ban',
//               style: TextStyle(
//                 color: isBanned ? Colors.green.shade700 : Colors.red.shade600,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
