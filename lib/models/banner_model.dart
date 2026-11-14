// lib/models/banner_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String imageUrl;
  final String fileName;
  final DateTime timestamp;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.fileName,
    required this.timestamp,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerModel(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'fileName': fileName,
      'timestamp': timestamp,
    };
  }
}