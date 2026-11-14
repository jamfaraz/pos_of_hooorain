// lib/controllers/banner_controller.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../constants.dart';
import '../models/banner_model.dart';

class BannerController extends GetxController {
  static BannerController get instance => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final picker = ImagePicker();

  Future<FilePickerResult?> _pickImageFile() async {
    try {
      return await (FilePicker as dynamic).platform.pickFiles(type: FileType.image);
    } catch (_) {
      try {
        final filePath = await (FilePicker as dynamic).getFilePath(type: FileType.image);
        if (filePath == null || filePath.isEmpty) return null;

        final file = File(filePath);
        final bytes = await file.readAsBytes();

        return FilePickerResult([
          PlatformFile(
            name: file.path.split(Platform.pathSeparator).last,
            path: file.path,
            size: bytes.length,
            bytes: bytes,
          ),
        ]);
      } catch (_) {
        return null;
      }
    }
  }

  // Upload or replace banner
  Future<void> uploadOrReplaceBanner(
    String category, {
    String? existingDocId,
    String? existingFileName,
  }) async {
    try {
      File? image;
      Uint8List? webImage;

      // Web - Use FilePicker
      if (kIsWeb) {
        final result = await _pickImageFile();
        if (result != null && result.files.single.bytes != null) {
          webImage = result.files.single.bytes!;
        }
      } else {
        // Mobile/Desktop - Use ImagePicker or FilePicker
        if (Platform.isAndroid || Platform.isIOS) {
          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            image = File(pickedFile.path);
          }
        } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          final result = await _pickImageFile();
          if (result != null && result.files.single.path != null) {
            image = File(result.files.single.path!);
          }
        }
      }

      if (image != null || webImage != null) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = _storage.ref().child('$category/$fileName');
        UploadTask uploadTask;

        if (kIsWeb) {
          uploadTask = storageRef.putData(webImage!);
        } else {
          uploadTask = storageRef.putFile(image!);
        }

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        if (existingDocId != null) {
          if (existingFileName != null) {
            await _storage.ref('$category/$existingFileName').delete();
          }
          await _firestore.collection(category).doc(existingDocId).update({
            'imageUrl': downloadUrl,
            'fileName': fileName,
          });
          Get.snackbar('Success', 'Banner updated successfully',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: kGreenColor,
              colorText: Colors.white);
        } else {
          await _firestore.collection(category).add({
            'imageUrl': downloadUrl,
            'fileName': fileName,
            'timestamp': FieldValue.serverTimestamp(),
          });
          Get.snackbar('Success', 'Banner added successfully',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: kGreenColor,
              colorText: Colors.white);
        }
      } else {
        Get.snackbar('Error', 'No image selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload banner: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  // Delete banner
  Future<void> deleteBanner(
    String category,
    String docId,
    String fileName,
  ) async {
    try {
      await _firestore.collection(category).doc(docId).delete();
      await _storage.ref('$category/$fileName').delete();
      Get.snackbar('Success', 'Banner deleted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: kGreenColor,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete banner: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  // Get banners stream
  Stream<List<BannerModel>> getBannersStream(String category) {
    return _firestore
        .collection(category)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList());
  }
}