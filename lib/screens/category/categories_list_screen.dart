// categories_list_screen.dart - Add visibility toggle UI
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:hoorain_pos/utils/toas_message.dart';
import '../../constants.dart';
import '../../controllers/add_category_controller.dart';
import '../../widgets/backbutton.dart';
import '../../widgets/common_dialog.dart';
import 'edit_category_screen.dart';

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CategoryController categoryController = Get.put(CategoryController());

  Future<void> _confirmDeleteLocation(String docId) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Delete category?',
      message:
          'Are you sure you want to delete this category? This action cannot be undone.',
      icon: Icons.delete_outline,
      iconColor: Theme.of(context).colorScheme.error,
      positiveButtonText: 'Delete',
    );
    if (confirmed != true) return;
    try {
      await _firestore.collection('categories').doc(docId).delete();
      MessageToast.showToast(msg: 'Category deleted successfully!');
    } catch (exception) {
      Get.snackbar(
        'Could not delete category',
        exception.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackNavigatingButton(color: kblack),
        title: Text(
          'Categories',
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categories').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kGreenColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? '';
                    final image = data['imageUrl'] ?? '';
                    final docId = docs[index].id;
                    final isVisible = data['isVisible'] ?? true;

                    return Container(
                      padding: EdgeInsets.all(9),
                      margin: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isVisible
                            ? Colors.grey.shade100
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isVisible
                              ? Colors.transparent
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 68.h,
                            width: 68.w,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: image,
                                placeholder: (context, url) =>
                                    _buildLoadingPlaceholder(),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isVisible)
                                  Text(
                                    'Hidden',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // NEW: Visibility Toggle Button
                          IconButton(
                            icon: Icon(
                              isVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: isVisible ? kGreenColor : Colors.red,
                            ),
                            onPressed: () {
                              categoryController.toggleCategoryVisibility(
                                docId,
                                isVisible,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: kGreenColor),
                            onPressed: () {
                              Get.to(
                                () => EditCategoryScreen(
                                  categoryId: docId,
                                  categoryName: name,
                                  categoryImage: image,
                                  subcategories: List<String>.from(
                                    data['subcategories'] ?? [],
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteLocation(docId),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return LoadingPlaceholder.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }
}
