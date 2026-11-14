// lib/screens/banners_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/loading_placeholder.dart';
import '../../constants.dart';
import '../../controllers/banner_controller.dart';
import '../../models/banner_model.dart';
import '../../widgets/common_dialog.dart';

class BannersScreen extends StatelessWidget {
  const BannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Banners Management',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2888),
        ),
        onPressed: () =>
            BannerController.instance.uploadOrReplaceBanner('banners'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: const _BannersList(category: 'banners'),
    );
  }
}

class _BannersList extends StatelessWidget {
  final String category;

  const _BannersList({required this.category});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BannerController());

    return StreamBuilder<List<BannerModel>>(
      stream: controller.getBannersStream(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingList();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 50.sp,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No banners available',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Tap the + button to add a new banner',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: snapshot.data!.length,
          separatorBuilder: (context, index) => Divider(
            color: const Color.fromRGBO(158, 158, 158, 1),
            thickness: 0.5,
            height: 28.h,
          ),
          itemBuilder: (context, index) {
            final banner = snapshot.data![index];
            return _BannerItem(
              banner: banner,
              category: category,
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingList() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: LoadingPlaceholder.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100.w, height: 100.w, color: Colors.white),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16.h,
                          color: Colors.white,
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: 120.w,
                          height: 14.h,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final BannerModel banner;
  final String category;
  final int index;

  const _BannerItem({
    required this.banner,
    required this.category,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BannerController());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner Image
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: CachedNetworkImage(
            imageUrl: banner.imageUrl,
            width: 100.w,
            height: 100.w,
            fit: BoxFit.cover,
            placeholder: (context, url) => LoadingPlaceholder.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 100.w,
                height: 100.w,
                color: Colors.white,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 100.w,
              height: 100.w,
              color: Colors.grey.shade100,
              child: Icon(
                Icons.broken_image,
                color: Colors.grey.shade400,
                size: 30.sp,
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        // Banner Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Banner ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Uploaded: ${_formatDate(banner.timestamp)}',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 16.h),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.edit, color: kGreenColor, size: 24.sp),
                    onPressed: () => showEditDialog(context, controller),
                    tooltip: "Edit Banner",
                  ),
                  SizedBox(width: 16.w),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.delete, color: Colors.red, size: 24.sp),
                    onPressed: () => showDeleteDialog(context, controller),
                    tooltip: "Delete Banner",
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void showEditDialog(BuildContext context, BannerController controller) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Update Banner',
        message: 'Do you want to replace this banner with a new image?',
        icon: Icons.edit,
        iconColor: kPrimaryColor,
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Replace',
        onPositiveButtonPressed: () async {
          Get.back();
          await controller.uploadOrReplaceBanner(
            category,
            existingDocId: banner.id,
            existingFileName: banner.fileName,
          );
        },
      ),
    );
  }

  void showDeleteDialog(BuildContext context, BannerController controller) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Delete Banner',
        message:
            'Are you sure you want to delete this banner? This action cannot be undone.',
        icon: Icons.warning_amber_outlined,
        iconColor: Colors.red,
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Delete',
        onPositiveButtonPressed: () async {
          Get.back();
          await controller.deleteBanner(category, banner.id, banner.fileName);
        },
      ),
    );
  }
}
