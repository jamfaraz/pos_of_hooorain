
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';
import 'package:hoorain_pos/utils/toas_message.dart';
import 'package:video_player/video_player.dart';
import '../models/product_model.dart';
import 'fetch_product_controller.dart';

class ProductController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxBool isLoading = false.obs;
  final RxBool isUpdating = false.obs;
  final Rx<File?> imageFile = Rx<File?>(null);
  final Rx<File?> videoFile = Rx<File?>(null);
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController ratingController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  final RxBool isFeatured = false.obs;
  final RxBool isOutOfStock = false.obs;
  final RxBool hasBulkPricing = false.obs; // New flag for bulk pricing

  // Bulk pricing controllers
  final RxList<BulkPricingRow> bulkPricingRows = <BulkPricingRow>[].obs;
  FetchProductController fetchProductController = Get.put(
    FetchProductController(),
  );

  @override
  void onInit() {
    super.onInit();
    // Add one empty row by default
    addBulkPricingRow();
  }

  @override
  void onClose() {
    nameController.dispose();
    priceController.dispose();
    mrpController.dispose();
    descriptionController.dispose();
    ratingController.dispose();
    for (var row in bulkPricingRows) {
      row.quantityController.dispose();
      row.priceController.dispose();
    }
    super.onClose();
  }

  void addBulkPricingRow({String? quantity, String? price}) {
    bulkPricingRows.add(BulkPricingRow(quantity: quantity, price: price));
  }

  void removeBulkPricingRow(int index) {
    if (bulkPricingRows.length > 1) {
      bulkPricingRows[index].quantityController.dispose();
      bulkPricingRows[index].priceController.dispose();
      bulkPricingRows.removeAt(index);
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageBytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child(
        'product_images/$fileName',
      );

      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        uploadProgress.value =
            (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
        uploadStatus.value = 'Uploading image...';
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  Future<String?> uploadVideo(File file) async {
    try {
      uploadStatus.value = 'Compressing video...';
      
      // Compress video
      final compressedVideo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedVideo == null) {
        throw Exception('Video compression failed');
      }

      final videoFile = File(compressedVideo.path!);
      final fileName = 'product_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance.ref().child(
        'product_videos/$fileName',
      );

      uploadStatus.value = 'Uploading video...';
      
      final uploadTask = ref.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        uploadProgress.value =
            (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Clean up compressed file
      if (compressedVideo.path != null) {
        File(compressedVideo.path!).delete();
      }
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Video upload failed: ${e.toString()}');
    }
  }

  Future<File> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        rotate: 0,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : file;
    } catch (e) {
      print('Compression error: $e - Using original file');
      return file;
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        final extension = pickedFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          throw Exception('Invalid image format. Please use JPG or PNG.');
        }

        final file = File(pickedFile.path);
        imageFile.value = file;
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  // Add these Rx variables at the top of ProductController class
final Rx<VideoPlayerController?> videoPlayerController = Rx<VideoPlayerController?>(null);

// Add this method to pick video
Future<void> pickVideo() async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (pickedFile != null) {
      final extension = pickedFile.path.split('.').last.toLowerCase();
      if (!['mp4', 'mov', 'avi'].contains(extension)) {
        throw Exception('Invalid video format. Please use MP4, MOV, or AVI.');
      }

      final file = File(pickedFile.path);
      videoFile.value = file;
      
      // Dispose existing controller
      if (videoPlayerController.value != null) {
        await videoPlayerController.value!.dispose();
      }
      
      // Initialize new video player for local file
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      videoPlayerController.value = controller;
    }
  } catch (e) {
    showError(e.toString());
  }
}

// Add this method to remove video
void removeVideo() {
  if (videoPlayerController.value != null) {
    videoPlayerController.value!.dispose();
    videoPlayerController.value = null;
  }
  videoFile.value = null;
}

// Add this method to initialize video player from URL
Future<void> initializeVideoPlayer(String url) async {
  try {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    videoPlayerController.value = controller;
  } catch (e) {
    print('Error initializing video player: $e');
  }
}

// Update _validateForm method
bool _validateForm() {
  if (nameController.text.isEmpty) {
    MessageToast.showToast(msg: 'Please enter product name');
    return false;
  }
  if (imageFile.value == null) {
    MessageToast.showToast(msg: 'Please select an image');
    return false;
  }
  if (priceController.text.isEmpty ||
      double.tryParse(priceController.text) == null) {
    MessageToast.showToast(msg: 'Please enter a valid price');
    return false;
  }
  if (mrpController.text.isEmpty ||
      double.tryParse(mrpController.text) == null) {
    MessageToast.showToast(msg: 'Please enter a valid MRP');
    return false;
  }
  if (descriptionController.text.isEmpty) {
    MessageToast.showToast(msg: 'Please enter description');
    return false;
  }
  
  // NEW: Validate quantity
  if (quantityController.text.isEmpty ||
      int.tryParse(quantityController.text) == null) {
    MessageToast.showToast(msg: 'Please enter a valid quantity');
    return false;
  }
  
  final quantity = int.parse(quantityController.text.trim());
  if (quantity <= 0) {
    MessageToast.showToast(msg: 'Quantity must be greater than 0');
    return false;
  }

  // Validate bulk pricing only if enabled
  if (hasBulkPricing.value) {
    for (final row in bulkPricingRows) {
      final qty = int.tryParse(row.quantityController.text.trim());
      final price = double.tryParse(row.priceController.text.trim());

      if (qty == null || qty <= 0) {
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
      if (qty > quantity) {
        MessageToast.showToast(
          msg: 'Bulk quantity cannot exceed total quantity',
        );
        return false;
      }
    }
  }

  return true;
}

// Update addProduct method
Future<void> addProduct(String category, String subcategory) async {
  try {
    if (!_validateForm()) return;
    if (category.isEmpty) {
      showError('Please select a category');
      return;
    }

    isLoading(true);
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Starting upload...';

    String? imageUrl;
    String? videoUrl;

    // Upload image
    if (imageFile.value != null) {
      final compressedFile = await compressImage(imageFile.value!);
      imageUrl = await uploadImage(compressedFile);
    }

    // Upload video
    if (videoFile.value != null) {
      videoUrl = await uploadVideo(videoFile.value!);
    }

    // Parse bulk pricing (only if enabled)
    final bulkPricing = <String, double>{};
    if (hasBulkPricing.value) {
      for (final row in bulkPricingRows) {
        final quantity = int.tryParse(row.quantityController.text.trim());
        final price = double.tryParse(row.priceController.text.trim());

        if (quantity != null && quantity > 0 && price != null && price > 0) {
          bulkPricing[quantity.toString()] = price;
        }
      }
    }

    final product = Product(
      name: nameController.text.trim(),
      category: category,
      subcategory: subcategory,
      price: double.parse(priceController.text.trim()),
      mrp: double.parse(mrpController.text.trim()),
      rating: ratingController.text.trim().isEmpty 
          ? 0.0 
          : double.parse(ratingController.text.trim()),
      description: descriptionController.text.trim(),
      isFeatured: isFeatured.value,
      isOutOfStock: int.parse(quantityController.text.trim()) == 0, // Set out of stock if quantity is 0
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      bulkPricing: bulkPricing,
      totalQuantity: int.parse(quantityController.text.trim()), // NEW
    );

    await _firestore.collection('products').add(product.toMap());

    _resetForm();
    Get.back();
    MessageToast.showToast(msg: 'Product added successfully');
  } catch (e) {
    showError('Failed to add product: ${e.toString()}');
  } finally {
    isLoading(false);
    uploadProgress.value = 0.0;
    uploadStatus.value = '';
  }
}

// Update updateProduct method
Future<void> updateProduct({
  required String productId,
  required String name,
  required String category,
  required double price,
  required double mrp,
  required double rating,
  required String description,
  required bool isFeatured,
  required bool isHide,
  required bool isOutOfStock,
  required Map<String, double> bulkPricing,
  required int totalQuantity, // NEW
  File? localImageFile,
  File? localVideoFile,
  String? existingImageUrl,
  String? existingVideoUrl,
}) async {
  try {
    isUpdating(true);
    String? updatedImageUrl = existingImageUrl;
    String? updatedVideoUrl = existingVideoUrl;

    if (localImageFile != null) {
      showSnackbar('Compressing and uploading new image...');
      final compressedFile = await compressImage(localImageFile);
      updatedImageUrl = await uploadImage(compressedFile);
    }

    if (localVideoFile != null) {
      showSnackbar('Compressing and uploading new video...');
      updatedVideoUrl = await uploadVideo(localVideoFile);
    }

    final updatedProduct = {
      'name': name.trim(),
      'category': category.trim(),
      'price': price,
      'mrp': mrp,
      'rating': rating,
      'description': description.trim(),
      'isFeatured': isFeatured,
      'isHide': isHide,
      'isOutOfStock': totalQuantity == 0 ? true : isOutOfStock, // Update out of stock based on quantity
      'imageUrl': updatedImageUrl,
      'videoUrl': updatedVideoUrl,
      'bulkPricing': bulkPricing,
      'totalQuantity': totalQuantity, // NEW
    };

    await _firestore
        .collection('products')
        .doc(productId)
        .update(updatedProduct);
    isUpdating(false);
    MessageToast.showToast(msg: 'Product updated successfully');
    fetchProductController.refreshSingleProduct(productId);
    Get.back();
  } catch (e) {
    isUpdating(false);
    showError('Failed to update product: $e');
  }
}

// Update _resetForm method
void _resetForm() {
  nameController.clear();
  priceController.clear();
  mrpController.clear();
  ratingController.clear();
  descriptionController.clear();
  quantityController.clear(); // NEW
  isFeatured.value = false;
  isOutOfStock.value = false;
  hasBulkPricing.value = false;
  imageFile.value = null;
  videoFile.value = null;
  bulkPricingRows.clear();
  addBulkPricingRow();
}



  double calculateTotalPrice(
    double basePrice,
    Map<String, double> bulkPricing,
    int quantity,
  ) {
    final thresholds = bulkPricing.keys
        .map((k) => int.tryParse(k) ?? 0)
        .where((t) => t > 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (final threshold in thresholds) {
      if (quantity >= threshold) {
        return bulkPricing[threshold.toString()]! * quantity;
      }
    }

    return basePrice * quantity;
  }

  void showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  void showSnackbar(String message) {
    Get.snackbar('Info', message, duration: 2.seconds);
  }
}

class BulkPricingRow {
  final TextEditingController quantityController;
  final TextEditingController priceController;

  BulkPricingRow({String? quantity, String? price})
      : quantityController = TextEditingController(text: quantity),
        priceController = TextEditingController(text: price);
}