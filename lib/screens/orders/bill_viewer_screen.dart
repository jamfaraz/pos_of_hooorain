import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

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
  final TransformationController _transformController =
      TransformationController();
  double _scale = 1;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

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
        MessageToast.showWarning(
          msg: 'Storage permission denied',
          title: 'Permission required',
        );
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

      MessageToast.showSuccess(
        msg: 'Bill saved to gallery',
        title: 'Download complete',
      );
    } on GalException catch (e) {
      MessageToast.showError(msg: e.type.message, title: 'Could not save bill');
    } catch (e) {
      MessageToast.showError(
        msg: 'Check your connection and try again.',
        title: 'Download failed',
      );
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bill',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.orderId != null)
              Text(
                '#${widget.orderId}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: () {
              _transformController.value = Matrix4.identity();
              setState(() => _scale = 1);
            },
            icon: const Icon(Icons.fit_screen_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 700;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 24,
              16,
              narrow ? 12 : 24,
              12,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 1,
                            maxScale: 5,
                            onInteractionUpdate: (_) {
                              final scale = _transformController.value
                                  .getMaxScaleOnAxis();
                              if ((scale - _scale).abs() > 0.01) {
                                setState(() => _scale = scale);
                              }
                            },
                            child: Center(
                              child: Image.network(
                                widget.billImageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  final value =
                                      progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: value,
                                      color: cs.primary,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Failed to load bill',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Text(
                              '${(_scale * 100).round()}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bill image',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              widget.orderId == null
                                  ? 'Hoorain bill'
                                  : 'Order #${widget.orderId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isDownloading ? null : _downloadBill,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(_isDownloading ? 'Saving...' : 'Download'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
