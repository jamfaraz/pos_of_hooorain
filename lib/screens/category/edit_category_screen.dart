import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/constants.dart';
import 'package:hoorain_pos/controllers/edit_category_controller.dart';
import 'package:hoorain_pos/widgets/backbutton.dart';
import 'package:hoorain_pos/widgets/primary_textfield.dart';
import 'package:hoorain_pos/widgets/round_button.dart';

import '../../widgets/common_dialog.dart';

class EditCategoryScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final String? categoryImage;
  final List<String> subcategories;

  const EditCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
    required this.subcategories,
  });

  @override
  Widget build(BuildContext context) {
    final EditCategoryController controller = Get.put(EditCategoryController());
    controller.initializeForEdit(
      name: categoryName,
      subcategories: subcategories,
      imageUrl: categoryImage,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackNavigatingButton(color: kblack),
        centerTitle: true,
        title: Text(
          'Edit Category',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => showsDeleteDialog(context, controller),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 33.h),
              // Image Picker
              GestureDetector(
                onTap: controller.pickCategoryImage,
                child: Container(
                  height: 188.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: _buildImageWidget(controller),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Category Name Field
              PrimaryTextField(
                controller: controller.nameController,
                hintText: 'Category Name',
                headerText: 'Enter Category Name',
              ),
              SizedBox(height: 16.h),

              // Subcategories Section
              Text(
                'Subcategories',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Subcategory List
              Obx(
                () => Column(
                  children: List.generate(
                    controller.subcategoryControllers.length,
                    (index) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: PrimaryTextField(
                            controller:
                                controller.subcategoryControllers[index],
                            hintText: 'Subcategory name',
                            onChanged: (value) => controller.update(),
                            headerText: '',
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            size: 24.w,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              controller.removeSubcategoryField(index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22),

              // Add Subcategory Button
              OutlinedButton(
                onPressed: controller.addSubcategoryField,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: Text(
                  'Add Subcategory',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: kGreenColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Update Button
              Obx(
                () => RoundButton(
                  text: 'Update Category',
                  onPressed: () => controller.updateCategory(categoryId),
                  isLoading: controller.isLoading.value,
                ),
              ),
              SizedBox(height: 22.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(EditCategoryController controller) {
    if (controller.imageFile.value != null) {
      return Image.file(controller.imageFile.value!, fit: BoxFit.cover);
    } else if (controller.imageUrl.value.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: controller.imageUrl.value,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator(color: kGreenColor)),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, size: 60.w),
        SizedBox(height: 8.h),
        Text(
          'Change Category Image',
          style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey),
        ),
      ],
    );
  }

  void showsDeleteDialog(
    BuildContext context,
    EditCategoryController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Delete',
        message:
            'Do you want to delete the category. This action cannot be undone?',
        icon: Icons.logout,
        iconColor: kPrimaryColor,
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Delete',
        onPositiveButtonPressed: () async {
          Navigator.pop(context);
          controller.deleteCategory(categoryId);
        },
      ),
    );
  }
}
