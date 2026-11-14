import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';
import '../../utils/toas_message.dart';

/// Full screen bill viewer with zoom + "Download" (saves to gallery).
class BillViewScreen extends StatefulWidget {
  final String billImageUrl;
  final String? orderId;

  const BillViewScreen({super.key, required this.billImageUrl, this.orderId});

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

class _BillViewScreenState extends State<BillViewScreen> {
  bool _isDownloading = false;

  String _fileExtension() {
    final path = Uri.parse(widget.billImageUrl).path.toLowerCase();
    for (final ext in ['png', 'jpeg', 'jpg', 'webp']) {
      if (path.endsWith('.$ext')) return ext;
    }
    return 'jpg';
  }

  Future<void> _downloadBill() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    File? tempFile;
    try {
      // 1. Gallery permission
      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        MessageToast.showToast(msg: 'Storage permission denied');
        return;
      }

      // 2. Download to a temp file
      final dir = await getTemporaryDirectory();
      final name =
          'bill_${widget.orderId ?? DateTime.now().millisecondsSinceEpoch}.${_fileExtension()}';
      final path = '${dir.path}/$name';
      await Dio().download(widget.billImageUrl, path);
      tempFile = File(path);

      // 3. Save to gallery
      await Gal.putImage(path, album: 'Hoorain Bills');

      MessageToast.showToast(msg: 'Bill saved to gallery');
    } on GalException catch (e) {
      MessageToast.showToast(msg: 'Could not save: ${e.type.message}');
    } catch (e) {
      MessageToast.showToast(msg: 'Download failed. Check your connection.');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bill',
              style: GoogleFonts.interTight(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (widget.orderId != null)
              Text(
                '#${widget.orderId}',
                style: GoogleFonts.interTight(
                  fontSize: 11.sp,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            widget.billImageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final value = progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null;
              return Center(
                child: CircularProgressIndicator(
                  value: value,
                  color: kGreenColor,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 48.w,
                  color: Colors.white54,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Failed to load bill',
                  style: GoogleFonts.interTight(
                    fontSize: 13.sp,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _downloadBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kPrimaryColor.withAlpha(120),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: _isDownloading
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _isDownloading ? 'Downloading...' : 'Download Bill',
                    style: GoogleFonts.interTight(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
