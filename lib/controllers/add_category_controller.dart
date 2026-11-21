// category_controller.dart - Add visibility toggle methods
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hoorain_pos/utils/toas_message.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController nameController = TextEditingController();
  final RxList<TextEditingController> subcategoryControllers =
      <TextEditingController>[].obs;
  final Rx<File?> imageFile = Rx<File?>(null);
  final RxString imageUrl = RxString('');
  final RxList<Category> categories = <Category>[].obs;
  final RxList<String> subcategories = <String>[].obs;
  final RxBool isLoading = RxBool(false);
  final RxBool isAdding = RxBool(false);
  final RxDouble uploadProgress = RxDouble(0.0);

  void addSubcategoryField() {
    subcategoryControllers.add(TextEditingController());
    update();
  }

  void removeSubcategoryField(int index) {
    if (index >= 0 && index < subcategoryControllers.length) {
      subcategoryControllers[index].dispose();
      subcategoryControllers.removeAt(index);
      update();
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      isLoading(true);
      categories.clear();
      final snapshot = await _firestore
          .collection('categories')
          .orderBy('name')
          .get();
      categories.assignAll(
        snapshot.docs.map((doc) => Category.fromMap(doc.data(), id: doc.id)),
      );
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to load categories: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  // NEW: Toggle category visibility
  Future<void> toggleCategoryVisibility(
    String categoryId,
    bool currentVisibility,
  ) async {
    try {
      await _firestore.collection('categories').doc(categoryId).update({
        'isVisible': !currentVisibility,
      });

      MessageToast.showToast(
        msg: !currentVisibility
            ? 'Category is now visible'
            : 'Category is now hidden',
      );

      // Reload categories
      await loadCategories();
    } catch (e) {
      MessageToast.showToast(
        msg: 'Failed to update visibility: ${e.toString()}',
      );
    }
  }

  Future<void> pickCategoryImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        imageFile.value = File(pickedFile.path);
        imageUrl.value = '';
      }
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to pick image: ${e.toString()}',
        title: 'Error',
      );
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('category_images/$fileName');
      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        uploadProgress.value =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to upload image: ${e.toString()}',
        title: 'Error',
      );
      return null;
    }
  }

  Future<void> addCategory() async {
    try {
      if (imageFile.value == null) {
        return MessageToast.showToast(msg: 'Please select image');
      }
      if (nameController.text.isEmpty) {
        return MessageToast.showToast(msg: 'Please enter category name');
      }

      final subcategories = subcategoryControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (subcategories.isEmpty) {
        return MessageToast.showToast(
          msg: 'Please add at least one subcategory',
        );
      }

      isAdding.value = true;

      String? uploadedImageUrl;
      if (imageFile.value != null) {
        uploadedImageUrl = await _uploadImage(imageFile.value!);
        if (uploadedImageUrl == null) {
          throw 'Failed to upload image';
        }
      }

      final categoryData = {
        'name': nameController.text.trim(),
        'imageUrl': uploadedImageUrl,
        'subcategories': subcategories,
        'isVisible': true, // NEW: Default to visible
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('categories').add(categoryData);
      resetForm();
      Get.back();
      MessageToast.showToast(msg: 'Category added successfully');
    } catch (e) {
      MessageToast.showError(msg: e.toString(), title: 'Error');
    } finally {
      isAdding.value = false;
    }
  }

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

  @override
  void onClose() {
    nameController.dispose();
    for (var controller in subcategoryControllers) {
      controller.dispose();
    }
    super.onClose();
  }
}
