import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class EditCategoryController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final RxList<TextEditingController> subcategoryControllers = <TextEditingController>[].obs;
  
  // Image handling
  final Rx<File?> imageFile = Rx<File?>(null);
  final RxString imageUrl = RxString('');
  
  // State
  final RxBool isLoading = RxBool(false);
  final RxDouble uploadProgress = RxDouble(0.0);

  @override
  void onClose() {
    nameController.dispose();
    for (var controller in subcategoryControllers) {
      controller.dispose();
    }
    super.onClose();
  }

  // Initialize data for editing
  void initializeForEdit({
    required String name,
    required List<String> subcategories,
    String? imageUrl,
  }) {
    nameController.text = name;
    this.imageUrl.value = imageUrl ?? '';
    
    // Initialize subcategory controllers
    subcategoryControllers.clear();
    for (var subcategory in subcategories) {
      subcategoryControllers.add(TextEditingController(text: subcategory));
    }
  }

  // Pick image from gallery
  Future<void> pickCategoryImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        imageFile.value = File(pickedFile.path);
        imageUrl.value = ''; // Reset URL when new image is picked
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage(File file) async {
    try {
      final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('category_images/$fileName');
      
      final uploadTask = ref.putFile(file);
      
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        uploadProgress.value = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload image: ${e.toString()}');
      return null;
    }
  }

  // Add a new subcategory field
  void addSubcategoryField() {
    subcategoryControllers.add(TextEditingController());
    update();
  }

  // Remove a subcategory field
  void removeSubcategoryField(int index) {
    if (index >= 0 && index < subcategoryControllers.length) {
      subcategoryControllers[index].dispose();
      subcategoryControllers.removeAt(index);
      update();
    }
  }

  // Update existing category
  Future<void> updateCategory(String categoryId) async {
    try {
      if (nameController.text.isEmpty) {
        throw 'Please enter category name';
      }

      // Get all subcategories (filter empty ones)
      final subcategories = subcategoryControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
          
      if (subcategories.isEmpty) {
        throw 'Please add at least one subcategory';
      }

      isLoading.value = true;
      String? currentImageUrl = imageUrl.value;

      // Upload new image if selected
      if (imageFile.value != null) {
        currentImageUrl = await _uploadImage(imageFile.value!);
        if (currentImageUrl == null) {
          isLoading.value = false;
          return;
        }
      }

      // Update in Firestore
      await _firestore.collection('categories').doc(categoryId).update({
        'name': nameController.text.trim(),
        'imageUrl': currentImageUrl,
        'subcategories': subcategories,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reset form
      resetForm();
      
      Get.back();
      MessageToast.showToast(msg: 'Category updated successfully');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    try {
      isLoading.value = true;
      await _firestore.collection('categories').doc(categoryId).delete();
      Get.back();
      Get.snackbar('Success', 'Category deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete category: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // Reset form
  void resetForm() {
    nameController.clear();
    for (var controller in subcategoryControllers) {
      controller.dispose();
    }
    subcategoryControllers.clear();
    imageFile.value = null;
    imageUrl.value = '';
    uploadProgress.value = 0.0;
  }
}