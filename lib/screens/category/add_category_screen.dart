import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/widgets/primary_textfield.dart';
import 'package:hoorain_pos/widgets/round_button.dart';
import '../../constants.dart';
import '../../controllers/add_category_controller.dart';
import '../../widgets/backbutton.dart';
import 'categories_list_screen.dart';

class AddCategoryScreen extends StatelessWidget {
  final CategoryController _controller = Get.put(CategoryController());

  AddCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackNavigatingButton(color: kblack),
        centerTitle: true,
        title: Text(
          'Add New Category',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
          actions: [
          IconButton(
            onPressed: () {
              Get.to(() => CategoriesListScreen());
            },
            icon: Icon(Icons.edit, color: kGreenColor),
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
                onTap: _controller.pickCategoryImage,
                child: Container(
                  height: 188.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: _controller.imageFile.value != null
                        ? Image.file(
                            _controller.imageFile.value!,
                            fit: BoxFit.cover,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 60.w),
                              SizedBox(height: 8.h),
                              Text(
                                'Add Category Image',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              
              // Category Name Field
              PrimaryTextField(
                controller: _controller.nameController,
                hintText: 'Category Name',
                headerText: 'Enter Category Name',
              ),
              SizedBox(height: 16.h),
              
             
               Text(
                'Subcategories',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Subcategory List
              Obx(() => Column(
                children: List.generate(
                  _controller.subcategoryControllers.length,
                  (index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: PrimaryTextField(
                          controller: _controller.subcategoryControllers[index],
                          hintText: 'Subcategory name',
                          onChanged: (value) => _controller.update(), headerText: '',
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 24.w, color: Colors.red),
                        onPressed: () => _controller.removeSubcategoryField(index),
                      ),
                    ],
                  ),
                ),
              )),
              SizedBox(
                height: 22,
              ),
              
              // Add Subcategory Button
              OutlinedButton(
                onPressed: _controller.addSubcategoryField,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),

                  side: BorderSide(color: Colors.grey.shade300)
                 
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
              
              // Submit Button
              Obx(
                () => RoundButton(
                  text: 'Add Category',
                  onPressed:  _controller.addCategory,
                  isLoading: _controller.isAdding.value,
                ),
              ),
               SizedBox(
                height: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

