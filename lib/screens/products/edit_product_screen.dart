import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/constants.dart';
import 'package:hoorain_pos/widgets/full_image.dart';
import 'package:hoorain_pos/widgets/primary_textfield.dart';
import 'package:hoorain_pos/widgets/round_button.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../../utils/toas_message.dart';
import '../../widgets/backbutton.dart';
import '../add_product/video_player_screen.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  final VoidCallback? onProductUpdated;

  const EditProductScreen({
    super.key,
    required this.product,
    this.onProductUpdated,
  });

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final ProductController productController = Get.put(ProductController());
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController mrpController;
  late TextEditingController ratingController;
  late TextEditingController descriptionController;
  late TextEditingController categoryController;
  late TextEditingController quantityController;
  late RxBool isFeatured;
  late RxBool isHide;
  late RxBool isOutOfStock;
  late RxBool hasBulkPricing;
  Rx<File?> localImageFile = Rx<File?>(null);
  Rx<File?> localVideoFile = Rx<File?>(null);
  String? imageUrl;
  String? videoUrl;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product.name);
    priceController = TextEditingController(
      text: widget.product.price.toString(),
    );
    mrpController = TextEditingController(text: widget.product.mrp.toString());
    ratingController = TextEditingController(
      text: widget.product.rating.toString(),
    );
    descriptionController = TextEditingController(
      text: widget.product.description,
    );
    categoryController = TextEditingController(text: widget.product.category);
    quantityController = TextEditingController(
      text: widget.product.totalQuantity.toString(),
    );
    isFeatured = RxBool(widget.product.isFeatured);
    isHide = RxBool(widget.product.isHide);
    isOutOfStock = RxBool(widget.product.isOutOfStock);
    hasBulkPricing = RxBool(widget.product.bulkPricing.isNotEmpty);
    imageUrl = widget.product.imageUrl;
    videoUrl = widget.product.videoUrl;

    _initializeBulkPricing();
  }

  void _initializeBulkPricing() {
    productController.bulkPricingRows.clear();

    if (widget.product.bulkPricing.isNotEmpty) {
      widget.product.bulkPricing.forEach((quantity, price) {
        productController.addBulkPricingRow(
          quantity: quantity,
          price: price.toString(),
        );
      });
    } else {
      productController.addBulkPricingRow();
    }
  }

  Future<void> _pickImage() async {
    await productController.pickImage();
    if (productController.imageFile.value != null) {
      localImageFile.value = productController.imageFile.value;
      imageUrl = null;
    }
  }

  Future<void> _pickVideo() async {
    await productController.pickVideo();
    if (productController.videoFile.value != null) {
      localVideoFile.value = productController.videoFile.value;
      videoUrl = null;
    }
  }

  void _playVideo() {
    if (localVideoFile.value != null) {
      Get.to(() => VideoPlayerScreen(
        videoUrl: '',
        localVideoFile: localVideoFile.value,
      ));
    } else if (videoUrl != null && videoUrl!.isNotEmpty) {
      Get.to(() => VideoPlayerScreen(
        videoUrl: videoUrl!,
        localVideoFile: null,
      ));
    }
  }

  void _removeVideo() {
    localVideoFile.value = null;
    videoUrl = null;
  }

  void _removeImage() {
    localImageFile.value = null;
    imageUrl = null;
  }

  Future<void> _updateProduct() async {
    if (_validateForm()) {
      final bulkPricing = <String, double>{};
      if (hasBulkPricing.value) {
        for (final row in productController.bulkPricingRows) {
          final quantity = row.quantityController.text.trim();
          final price = double.tryParse(row.priceController.text.trim());

          if (quantity.isNotEmpty && price != null && price > 0) {
            bulkPricing[quantity] = price;
          }
        }
      }

      await productController.updateProduct(
        productId: widget.product.id ?? '',
        name: nameController.text.trim(),
        category: categoryController.text.trim(),
        price: double.parse(priceController.text.trim()),
        mrp: double.parse(mrpController.text.trim()),
        rating: double.parse(ratingController.text.trim()),
        description: descriptionController.text.trim(),
        isFeatured: isFeatured.value,
        isHide: isHide.value,
        isOutOfStock: isOutOfStock.value,
        bulkPricing: bulkPricing,
        totalQuantity: int.parse(quantityController.text.trim()),
        localImageFile: localImageFile.value,
        localVideoFile: localVideoFile.value,
        existingImageUrl: imageUrl,
        existingVideoUrl: videoUrl,
      );

      if (widget.onProductUpdated != null) {
        widget.onProductUpdated!();
      }
    }
  }

  bool _validateForm() {
    if (nameController.text.isEmpty) {
      MessageToast.showToast(msg: 'Please enter product name');
      return false;
    }
    if (categoryController.text.isEmpty) {
      MessageToast.showToast(msg: 'Please enter product category');
      return false;
    }
    if (priceController.text.isEmpty ||
        double.tryParse(priceController.text) == null) {
      MessageToast.showToast(msg: 'Please enter a valid price');
      return false;
    }
    if (descriptionController.text.isEmpty) {
      MessageToast.showToast(msg: 'Please enter description');
      return false;
    }
    
    if (quantityController.text.isEmpty ||
        int.tryParse(quantityController.text) == null) {
      MessageToast.showToast(msg: 'Please enter a valid quantity');
      return false;
    }
    
    final quantity = int.parse(quantityController.text.trim());
    if (quantity < 0) {
      MessageToast.showToast(msg: 'Quantity cannot be negative');
      return false;
    }

    if (hasBulkPricing.value) {
      for (final row in productController.bulkPricingRows) {
        final bulkQuantity = int.tryParse(row.quantityController.text.trim());
        final price = double.tryParse(row.priceController.text.trim());

        if (bulkQuantity == null || bulkQuantity <= 0) {
          MessageToast.showToast(
            msg: 'Please enter valid quantity for bulk pricing',
          );
          return false;
        }
        if (price == null || price <= 0) {
          MessageToast.showToast(
            msg: 'Please enter valid price for bulk pricing',
          );
          return false;
        }
        if (price >= double.parse(priceController.text.trim())) {
          MessageToast.showToast(
            msg: 'Bulk price must be less than regular price',
          );
          return false;
        }
        if (bulkQuantity > quantity) {
          MessageToast.showToast(
            msg: 'Bulk quantity cannot exceed total quantity',
          );
          return false;
        }
      }
    }

    return true;
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    mrpController.dispose();
    ratingController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Edit Product',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        leading: BackNavigatingButton(color: kPrimaryColor),
        actions: [
          Obx(
            () => productController.isUpdating.value
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: kPrimaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _updateProduct,
                  ),
          ),
        ],
      ),
      body: Obx(() {
        if (productController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: kGreenColor,
              strokeWidth: 2,
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Section
              _buildImageSection(),
              const SizedBox(height: 16),

              // Product Video Section
              _buildVideoSection(),
              const SizedBox(height: 16),

              // Product Name
              PrimaryTextField(
                controller: nameController,
                hintText: 'Enter Product Name',
                headerText: 'Product Name',
              ),
              const SizedBox(height: 16.0),

              // Category and Rating
              Row(
                children: [
                  Expanded(
                    child: PrimaryTextField(
                      controller: categoryController,
                      hintText: 'Enter Category',
                      readOnly: true,
                      headerText: 'Category',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: PrimaryTextField(
                      controller: ratingController,
                      hintText: 'Enter rating',
                      headerText: 'Rating (Optional)',
                      fieldType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Price and MRP
              Row(
                children: [
                  Expanded(
                    child: PrimaryTextField(
                      controller: priceController,
                      hintText: 'Enter price',
                      headerText: 'Price',
                      fieldType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: PrimaryTextField(
                      controller: mrpController,
                      hintText: 'Enter manufacture price',
                      headerText: 'MRP Price',
                      fieldType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Total Quantity Field
              PrimaryTextField(
                controller: quantityController,
                hintText: 'Enter total available quantity',
                headerText: 'Total Quantity',
                fieldType: TextInputType.number,
              ),
              const SizedBox(height: 16.0),

              // Bulk Pricing Toggle
              Obx(
                () => CheckboxListTile(
                  title: Text(
                    'Enable Bulk Pricing',
                    style: GoogleFonts.inter(fontSize: 15.sp),
                  ),
                  subtitle: Text(
                    'Set discounted prices for bulk purchases',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  activeColor: kPrimaryColor,
                  value: hasBulkPricing.value,
                  onChanged: (bool? value) {
                    hasBulkPricing.value = value ?? false;
                  },
                ),
              ),

              // Bulk Pricing Section
              Obx(() {
                if (hasBulkPricing.value) {
                  return _buildBulkPricingSection();
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 16.0),

              // Description
              PrimaryTextField(
                controller: descriptionController,
                hintText: 'Enter description',
                maxLines: 3,
                headerText: 'Description',
              ),
              const SizedBox(height: 16.0),

              // Visibility Switch
              Obx(
                () => Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: isHide.value
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isHide.value
                          ? Colors.orange.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Row(
                      children: [
                        Icon(
                          isHide.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: isHide.value ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isHide.value
                              ? 'Hidden from Customers'
                              : 'Visible to Customers',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                            color: isHide.value
                                ? Colors.orange.shade800
                                : kGreenColor,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isHide.value
                          ? 'Product will not be shown in the store'
                          : 'Product is visible to all customers',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isHide.value
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                    activeColor: kGreenColor,
                    activeTrackColor: Colors.white,
                    inactiveThumbColor: Colors.orange,
                    inactiveTrackColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    value: !isHide.value,
                    onChanged: (bool value) {
                      isHide.value = !value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // Out of Stock Switch
              Obx(
                () => Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: isOutOfStock.value
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isOutOfStock.value
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Row(
                      children: [
                        Icon(
                          isOutOfStock.value
                              ? Icons.inventory_2_outlined
                              : Icons.check_circle_outline,
                          color: isOutOfStock.value ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isOutOfStock.value
                              ? 'Out of Stock'
                              : 'In Stock',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                            color: isOutOfStock.value
                                ? Colors.red.shade800
                                : kGreenColor,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isOutOfStock.value
                          ? 'Customers cannot purchase this product'
                          : 'Available for purchase',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isOutOfStock.value
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                    activeColor: Colors.red,
                    activeTrackColor: Colors.white,
                    inactiveThumbColor: Colors.green,
                    inactiveTrackColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    value: isOutOfStock.value,
                    onChanged: (bool value) {
                      isOutOfStock.value = value;
                      if (!value && int.parse(quantityController.text) == 0) {
                        Get.snackbar(
                          'Warning',
                          'Product has 0 quantity. Please update quantity.',
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // Featured Checkbox
              Obx(
                () => CheckboxListTile(
                  title: Text(
                    'Featured Product',
                    style: GoogleFonts.interTight(),
                  ),
                  subtitle: Text(
                    'Show this product in featured section',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  activeColor: kPrimaryColor,
                  value: isFeatured.value,
                  onChanged: (bool? value) {
                    if (value != null) {
                      isFeatured.value = value;
                    }
                  },
                ),
              ),
              const SizedBox(height: 24.0),

              // Update Button
              Obx(
                () => RoundButton(
                  text: 'Update Product',
                  isLoading: productController.isUpdating.value,
                  onPressed: _updateProduct,
                ),
              ),
              const SizedBox(height: 8.0),

              // Upload Progress
              Obx(
                () => productController.uploadProgress.value > 0
                    ? Column(
                        children: [
                          LinearProgressIndicator(
                            value: productController.uploadProgress.value / 100,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            productController.uploadStatus.value,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }),
    );
  }

Widget _buildImageSection() {
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
      
      // Image Container with better UX
      Container(
        height: 188.h,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(12.0),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Display
              Obx(() {
                if (localImageFile.value != null) {
                  // Newly picked image
                  return Image.file(
                    localImageFile.value!,
                    fit: BoxFit.contain,
                  );
                } else if (imageUrl != null && imageUrl!.isNotEmpty) {
                  // Existing image from URL
                  return CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // No image
                  return Container(
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No image selected',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }),
              
              // Overlay with action buttons
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    // Delete Button - ONLY for newly selected image
                    Obx(() {
                      if (localImageFile.value != null) {
                        return Container(
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
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                            onPressed: _removeImage,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    }),
                    
                    SizedBox(width: 8),
                    
                    // Change Image Button (always visible)
                    Container(
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: _pickImage,
                        padding: EdgeInsets.all(6),
                        constraints: BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // See Full Image Button (only for existing URL images, not for new selections)
              if (imageUrl != null && 
                  imageUrl!.isNotEmpty && 
                  localImageFile.value == null)
                Positioned(
                  bottom: 7,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        Get.to(() => FullImageScreen(imageUrl: imageUrl ?? ''));
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'View Full Image',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      
      // Info Message about current image state
      Obx(() {
        if (localImageFile.value != null) {
          return Padding(
            padding: EdgeInsets.only(top: 8.sp),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New image selected. Tap delete button to cancel or save to update.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (imageUrl != null && imageUrl!.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 8.sp),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current image loaded. Tap edit button to change.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Padding(
            padding: EdgeInsets.only(top: 8.sp),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No image selected. Tap edit button to add an image.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }),
      
      // Help text
      Padding(
        padding: EdgeInsets.only(top: 8.sp),
        child: Text(
          'Tap the edit button to change image. Supports JPG, PNG, GIF',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    ],
  );
}

  Widget _buildVideoSection() {
    final currentImageUrl = localImageFile.value != null 
        ? null 
        : (imageUrl ?? widget.product.imageUrl);
    
    final hasVideo = (videoUrl != null && videoUrl!.isNotEmpty) || 
                     localVideoFile.value != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Video (Optional)',
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasVideo ? _playVideo : _pickVideo,
          child: Container(
            height: 150.h,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: hasVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail with product image
                        Container(
                          color: Colors.grey[200],
                          child: Stack(
                            children: [
                              if (currentImageUrl != null && currentImageUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: currentImageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.video_library,
                                      size: 40,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_circle_filled,
                                        size: 48,
                                        color: kPrimaryColor,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        localVideoFile.value != null
                                            ? 'New video selected'
                                            : 'Video available',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Dark overlay
                              Container(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              
                              // Play button
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.black,
                                    size: 50.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Remove button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeVideo,
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
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 42,
                            color: Colors.grey.shade700,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add video',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'MP4, MOV, AVI up to 5 minutes',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (hasVideo)
          Padding(
            padding: EdgeInsets.only(top: 8.sp),
            child: Text(
              localVideoFile.value != null 
                  ? 'New video selected - tap to watch'
                  : 'Video available - tap to watch',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: kGreenColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBulkPricingSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bulk Pricing Tiers',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  productController.addBulkPricingRow();
                },
                child: Text(
                  '+ Add Tier',
                  style: GoogleFonts.inter(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            'Set discounted prices for bulk purchases',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16.0),

          // Bulk Pricing Rows
          Obx(
            () => Column(
              children: [
                for (
                  int i = 0;
                  i < productController.bulkPricingRows.length;
                  i++
                )
                  _buildBulkPricingRow(i),
              ],
            ),
          ),
        ],
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
              controller:
                  productController.bulkPricingRows[index].quantityController,
              hintText: 'Min quantity',
              fieldType: TextInputType.number,
              headerText: 'Quantity',
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            flex: 3,
            child: PrimaryTextField(
              controller:
                  productController.bulkPricingRows[index].priceController,
              hintText: 'Price per item',
              headerText: 'Price',
              fieldType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () {
              if (productController.bulkPricingRows.length > 1) {
                productController.removeBulkPricingRow(index);
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