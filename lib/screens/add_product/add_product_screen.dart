import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/controllers/add_category_controller.dart';
import 'package:hoorain_pos/utils/toas_message.dart';
import 'package:hoorain_pos/widgets/primary_textfield.dart';
import 'package:hoorain_pos/widgets/round_button.dart';
import '../../constants.dart';
import '../../controllers/product_controller.dart';
import '../../models/category_model.dart';
import '../../widgets/backbutton.dart';
import 'video_player_screen.dart';

class AddProductScreen extends StatelessWidget {
  AddProductScreen({super.key});

  final ProductController _controller = Get.put(ProductController());
  final Rx<Category?> selectedCategory = Rx<Category?>(null);
  final RxString selectedSubcategory = RxString('');

  final CategoryController categoryController = Get.put(CategoryController());

  void _playVideo() {
    if (_controller.videoFile.value != null) {
      // For local file (newly selected video)
      Get.to(() => VideoPlayerScreen(
        videoUrl: '', // Empty for local file
        localVideoFile: _controller.videoFile.value,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const BackNavigatingButton(color: kblack),
        centerTitle: true,
        title: Text(
          'Add Product',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Obx(
            () => _controller.isLoading.value
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: kPrimaryColor),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      _controller.addProduct(
                        selectedCategory.value?.name.toString() ?? '',
                        selectedSubcategory.value.toString(),
                      );
                    },
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Upload Progress
            Obx(
              () => _controller.uploadProgress.value > 0
                  ? Column(
                      children: [
                        LinearProgressIndicator(
                          value: _controller.uploadProgress.value / 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_controller.uploadStatus.value}: ${_controller.uploadProgress.value.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Product Image
            _buildImagePicker(),
            const SizedBox(height: 20),

            // Product Video
            _buildVideoPicker(),
            const SizedBox(height: 20),

            // Product Name and Rating
            Row(
              children: [
                Expanded(
                  child: PrimaryTextField(
                    controller: _controller.nameController,
                    hintText: 'Enter Product Name',
                    headerText: 'Product Name',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: PrimaryTextField(
                    controller: _controller.ratingController,
                    hintText: 'Enter rating',
                    headerText: 'Rating (Optional)',
                    fieldType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            // Category Dropdown
            Obx(() {
              if (categoryController.isLoading.value) {
                return const CircularProgressIndicator(color: kPrimaryColor);
              }
              return CommonDropdown<Category>(
                label: 'Category',
                items: categoryController.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                value: selectedCategory.value,
                onChanged: (Category? newValue) {
                  selectedCategory.value = newValue;
                  selectedSubcategory.value = '';
                },
                hint: 'Select a category',
              );
            }),

            // Subcategory Dropdown
            Obx(() {
              if (selectedCategory.value == null) {
                return const SizedBox.shrink();
              }

              final subcategories = selectedCategory.value?.subcategories ?? [];
              if (subcategories.isEmpty) {
                return const SizedBox.shrink();
              }

              return CommonDropdown<String>(
                label: 'Subcategory',
                items: subcategories
                    .map(
                      (subcat) => DropdownMenuItem(
                        value: subcat,
                        child: Text(subcat),
                      ),
                    )
                    .toList(),
                value: selectedSubcategory.value.isNotEmpty
                    ? selectedSubcategory.value
                    : null,
                onChanged: (String? newValue) {
                  selectedSubcategory.value = newValue ?? '';
                },
                hint: 'Select a subcategory',
              );
            }),

            // Price and MRP
            Row(
              children: [
                Expanded(
                  child: PrimaryTextField(
                    controller: _controller.priceController,
                    hintText: 'Enter Product price',
                    headerText: 'Product Price',
                    fieldType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: PrimaryTextField(
                    controller: _controller.mrpController,
                    hintText: 'Enter Manufacture price',
                    headerText: 'MRP Price',
                    fieldType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            // NEW: Total Quantity Field
            PrimaryTextField(
              controller: _controller.quantityController,
              hintText: 'Enter total available quantity',
              headerText: 'Total Quantity',
              fieldType: TextInputType.number,
              // subtitle: 'Set the total number of items available in stock',
            ),

            const SizedBox(height: 13),

            // Bulk Pricing Toggle
            Obx(
              () => CheckboxListTile(
                title: Text(
                  'Enable Bulk Pricing',
                  style: GoogleFonts.inter(
                       fontSize: 13.sp,
                       color: _controller.hasBulkPricing.value ? kPrimaryColor : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Set discounted prices for bulk purchases',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    
                    color: Colors.grey.shade600,
                  ),
                ),
                activeColor: kPrimaryColor,
                value: _controller.hasBulkPricing.value,
                onChanged: (bool? value) {
                  _controller.hasBulkPricing.value = value ?? false;
                },
              ),
            ),

            // Bulk Pricing Section (only shown if enabled)
            Obx(() {
              if (_controller.hasBulkPricing.value) {
                return _buildBulkPricingSection();
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 13),

            // Description
            PrimaryTextField(
              controller: _controller.descriptionController,
              hintText: 'Enter description',
              headerText: 'Product Description',
              maxLines: 3,
            ),

            const SizedBox(height: 12),

            // Featured Checkbox
            Obx(
              () => CheckboxListTile(
                title: Text(
                  'Featured Product',
                  style: GoogleFonts.inter(
                    color: _controller.isFeatured.value ? kPrimaryColor : null,
                     fontSize: 13.sp,
                    fontWeight: FontWeight.w500,),
                ),
                subtitle: Text(
                  'Show this product in featured section',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                activeColor: kPrimaryColor,
                value: _controller.isFeatured.value,
                onChanged: (bool? value) {
                  _controller.isFeatured.value = value ?? false;
                },
              ),
            ),

            // Out of Stock Checkbox
            Obx(
              () => CheckboxListTile(
                title: Text(
                  'Out of Stock',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: _controller.isOutOfStock.value ? Colors.red : null,
                  ),
                ),
                subtitle: Text(
                  _controller.isOutOfStock.value
                      ? 'Customers cannot purchase this product'
                      : 'Product is available for purchase',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _controller.isOutOfStock.value
                        ? Colors.red.shade600
                        : Colors.grey.shade600,
                  ),
                ),
                activeColor: Colors.red,
                value: _controller.isOutOfStock.value,
                onChanged: (bool? value) {
                  _controller.isOutOfStock.value = value ?? false;
                },
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            Obx(
              () => RoundButton(
                text: 'Add Product',
                isLoading: _controller.isLoading.value,
                onPressed: () {
                  if (selectedCategory.value?.name.isEmpty ?? true) {
                    MessageToast.showToast(msg: 'Please select category');
                  } else {
                    _controller.addProduct(
                      selectedCategory.value?.name.toString() ?? '',
                      selectedSubcategory.value.toString(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Image',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (_controller.imageFile.value != null) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _controller.imageFile.value!,
                    height: 188.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _controller.pickImage,
                  child: const Text('Change Image'),
                ),
              ],
            );
          } else {
            return GestureDetector(
              onTap: _controller.pickImage,
              child: Container(
                height: 188.h,
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey.shade800,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload Image',
                      style: GoogleFonts.interTight(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Video (Optional)',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (_controller.videoFile.value != null) {
            return Column(
              children: [
                GestureDetector(
                  onTap: _playVideo,
                  child: Container(
                    height: 188.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video Thumbnail Placeholder
                        Container(
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 60,
                                color: kPrimaryColor,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to play video',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Video selected',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Play button overlay
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _playVideo,
                              child: Container(),
                            ),
                          ),
                        ),
                        
                        // Remove button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              _controller.removeVideo();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                size: 24,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _controller.pickVideo,
                  child: const Text('Change Video'),
                ),
              ],
            );
          } else {
            return GestureDetector(
              onTap: _controller.pickVideo,
              child: Container(
                height: 188.h,
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 40,
                      color: Colors.grey.shade800,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload Video (Optional)',
                      style: GoogleFonts.interTight(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'MP4, MOV, AVI up to 5 minutes',
                      style: GoogleFonts.interTight(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildBulkPricingSection() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bulk Pricing',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _controller.addBulkPricingRow();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ Add Tier',
                      style: GoogleFonts.inter(
                        color: kGreenColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Set discounted prices for bulk purchases',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 16),

            // Bulk pricing rows
            Obx(
              () => Column(
                children: [
                  for (int i = 0; i < _controller.bulkPricingRows.length; i++)
                    _buildBulkPricingRow(i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkPricingRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PrimaryTextField(
              controller: _controller.bulkPricingRows[index].quantityController,
              hintText: 'Min quantity',
              fieldType: TextInputType.number,
              headerText: 'Quantity',
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: PrimaryTextField(
              controller: _controller.bulkPricingRows[index].priceController,
              hintText: 'Price per item',
              headerText: 'Price',
              fieldType: TextInputType.number,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () {
              if (_controller.bulkPricingRows.length > 1) {
                _controller.removeBulkPricingRow(index);
              } else {
                MessageToast.showToast(msg: 'At least one tier is required');
              }
            },
          ),
        ],
      ),
    );
  }
}
