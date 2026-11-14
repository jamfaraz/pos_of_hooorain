import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

class MultiImageUploader extends StatefulWidget {
  const MultiImageUploader({
    required this.value,
    required this.onChanged,
    this.maxImages = 6,
    this.compact = false,
    super.key,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final int maxImages;
  final bool compact;

  @override
  State<MultiImageUploader> createState() => _MultiImageUploaderState();
}

class _MultiImageUploaderState extends State<MultiImageUploader> {
  final _uuid = const Uuid();
  bool _dragging = false;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      await _upload(
        result.files.map((file) => (file.name, file.bytes)).toList(),
      );
    }
  }

  Future<void> _upload(List<(String, Uint8List?)> files) async {
    final available = widget.maxImages - widget.value.length;
    if (available <= 0) return;
    final pending = files.take(available).toList();
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    final urls = [...widget.value];
    try {
      for (var index = 0; index < pending.length; index++) {
        final (name, bytes) = pending[index];
        if (bytes == null || bytes.isEmpty) {
          throw StateError('Could not read "$name". Choose the file again.');
        }
        final ref = FirebaseStorage.instance.ref(
          'product-images/${_uuid.v4()}-${name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}',
        );
        final task = ref.putData(bytes);
        final subscription = task.snapshotEvents.listen((snapshot) {
          if (mounted && snapshot.totalBytes > 0) {
            setState(
              () => _progress =
                  (index + snapshot.bytesTransferred / snapshot.totalBytes) /
                  pending.length,
            );
          }
        });
        await task;
        await subscription.cancel();
        urls.add(await ref.getDownloadURL());
      }
      widget.onChanged(urls);
    } catch (exception) {
      setState(() => _error = exception.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.compact ? 96.0 : 76.0;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        final files = <(String, Uint8List?)>[];
        for (final file in detail.files) {
          files.add((file.name, await file.readAsBytes()));
        }
        await _upload(files);
      },
      child: Container(
        padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _dragging ? theme.colorScheme.primaryContainer : null,
          border: widget.compact
              ? null
              : Border.all(
                  color: _dragging
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < widget.value.length; index++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          widget.value[index],
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: size,
                            height: size,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(PhosphorIconsRegular.imageBroken),
                          ),
                        ),
                      ),
                      if (index == 0)
                        const Positioned(
                          left: 3,
                          bottom: 3,
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('Cover'),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove image',
                          onPressed: () {
                            final images = [...widget.value]..removeAt(index);
                            widget.onChanged(images);
                          },
                          icon: const Icon(PhosphorIconsRegular.x, size: 15),
                        ),
                      ),
                    ],
                  ),
                if (widget.value.length < widget.maxImages)
                  widget.compact
                      ? InkWell(
                          onTap: _uploading ? null : _pickFiles,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.uploadSimple,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Add photos',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickFiles,
                          icon: const Icon(PhosphorIconsRegular.uploadSimple),
                          label: const Text('Add images'),
                        ),
              ],
            ),
            if (_uploading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (!widget.compact) ...[
              const SizedBox(height: 4),
              Text(
                'Up to ${widget.maxImages} images. Drop files here; the first image is the cover.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
