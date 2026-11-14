import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/product_management_controller.dart';
import '../../models/product_record.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/multi_image_uploader.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/side_drawer.dart';

class ProductEditorDrawer extends StatefulWidget {
  const ProductEditorDrawer({this.product, this.categoryId, super.key});

  final ProductRecord? product;
  final String? categoryId;

  static Future<void> show(ProductRecord? product, {String? categoryId}) =>
      showDialog<void>(
        context: Get.context!,
        builder: (_) =>
            ProductEditorDrawer(product: product, categoryId: categoryId),
      );

  @override
  State<ProductEditorDrawer> createState() => _ProductEditorDrawerState();
}

class _ProductEditorDrawerState extends State<ProductEditorDrawer> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late final TextEditingController _videoUrl;
  final List<Map<String, TextEditingController>> _tiers = [];
  List<String> _images = [];
  String? _categoryId;
  String? _subcategory;
  bool _bulkEnabled = false;
  bool _featured = false;
  bool _active = true;
  bool _saving = false;
  bool _uploadingVideo = false;
  double _videoProgress = 0;
  String? _error;
  String? _videoError;

  ProductManagementController get _controller => Get.find();

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _fields = {
      'name': TextEditingController(text: product?.name ?? ''),
      'sku': TextEditingController(text: product?.sku ?? ''),
      'description': TextEditingController(text: product?.description ?? ''),
      'mrp': TextEditingController(text: _text(product?.mrp)),
      'cost': TextEditingController(text: _text(product?.cost)),
      'homePrice': TextEditingController(text: _text(product?.homePrice)),
      'shopPrice': TextEditingController(text: _text(product?.shopPrice)),
      'stock': TextEditingController(text: _text(product?.stock)),
    };
    _videoUrl = TextEditingController(text: product?.videoUrl ?? '');
    _categoryId = product?.categoryId.isEmpty == true
        ? widget.categoryId
        : product?.categoryId ?? widget.categoryId;
    _subcategory = product?.subcategory.isEmpty == true
        ? null
        : product?.subcategory;
    _images = [...?product?.images];
    _bulkEnabled = product?.bulkEnabled ?? false;
    _featured = product?.featured ?? false;
    _active = product?.active ?? true;
    for (final tier in product?.tiers ?? const []) {
      _addTier(
        qty: (tier['qty'] as num?)?.toInt() ?? 0,
        homePrice: (tier['homePrice'] as num?)?.toDouble() ?? 0,
        shopPrice: (tier['shopPrice'] as num?)?.toDouble() ?? 0,
      );
    }
  }

  String _text(num? value) => value == null || value == 0 ? '' : '$value';
  double _number(String key) => double.tryParse(_fields[key]!.text.trim()) ?? 0;

  void _addTier({int qty = 0, double homePrice = 0, double shopPrice = 0}) {
    _tiers.add({
      'qty': TextEditingController(text: qty == 0 ? '' : '$qty'),
      'homePrice': TextEditingController(
        text: homePrice == 0 ? '' : '$homePrice',
      ),
      'shopPrice': TextEditingController(
        text: shopPrice == 0 ? '' : '$shopPrice',
      ),
    });
    setState(() {});
  }

  void _removeTier(int index) {
    for (final field in _tiers.removeAt(index).values) {
      field.dispose();
    }
    setState(() {});
  }

  Future<void> _uploadVideo() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(type: FileType.video, withData: true);
    } catch (exception) {
      if (mounted) setState(() => _videoError = exception.toString());
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _videoError = 'Could not read the selected video.');
      return;
    }

    setState(() {
      _uploadingVideo = true;
      _videoProgress = 0;
      _videoError = null;
    });
    try {
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final reference = FirebaseStorage.instance.ref().child(
        'product-videos/${DateTime.now().microsecondsSinceEpoch}-$safeName',
      );
      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        _ => 'application/octet-stream',
      };
      final task = reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (mounted && snapshot.totalBytes > 0) {
          setState(
            () => _videoProgress =
                snapshot.bytesTransferred / snapshot.totalBytes,
          );
        }
      });
      try {
        await task;
      } finally {
        await subscription.cancel();
      }
      _videoUrl.text = await reference.getDownloadURL();
    } catch (exception) {
      if (mounted) setState(() => _videoError = exception.toString());
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final mrp = _number('mrp');
    final home = _number('homePrice');
    final shop = _number('shopPrice');
    if (mrp > 0 && mrp < (home > shop ? home : shop)) {
      setState(() => _error = 'MRP cannot be lower than either selling price.');
      return;
    }
    final tiers = <Map<String, dynamic>>[];
    for (final row in _tiers) {
      final qty = int.tryParse(row['qty']!.text) ?? 0;
      final homePrice = double.tryParse(row['homePrice']!.text) ?? 0;
      final shopPrice = double.tryParse(row['shopPrice']!.text) ?? 0;
      if (qty > 0 && homePrice > 0 && shopPrice > 0) {
        tiers.add({'qty': qty, 'homePrice': homePrice, 'shopPrice': shopPrice});
      }
    }
    if (_bulkEnabled && tiers.isEmpty) {
      setState(() => _error = 'Add at least one valid bulk tier.');
      return;
    }
    tiers.sort((a, b) => (a['qty'] as int).compareTo(b['qty'] as int));
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final category = _controller.categories.firstWhereOrNull(
        (item) => item.id == _categoryId,
      );
      final product = ProductRecord(
        id: widget.product?.id,
        name: _fields['name']!.text.trim(),
        category: category?.name ?? '',
        categoryId: _categoryId ?? '',
        subcategory: _subcategory ?? '',
        sku: _fields['sku']!.text.trim(),
        description: _fields['description']!.text.trim(),
        mrp: mrp,
        cost: _number('cost'),
        homePrice: home,
        shopPrice: shop,
        stock: _number('stock').toInt(),
        reorderLevel: widget.product?.reorderLevel ?? 0,
        images: _images,
        videoUrl: _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
        featured: _featured,
        active: _active,
        bulkEnabled: _bulkEnabled,
        tiers: tiers,
        ratingAvg: widget.product?.ratingAvg ?? 0,
        ratingCount: widget.product?.ratingCount ?? 0,
      );
      await _controller.saveProduct(product);
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      if (mounted) setState(() => _error = exception.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteProduct() async {
    final product = widget.product;
    if (product == null || product.id == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final deleted = await _controller.deleteOrHide(product);
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.snackbar(
        deleted ? 'Product deleted' : 'Product hidden',
        deleted
            ? 'The product was deleted.'
            : 'This product has sales history, so it was hidden instead.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (exception) {
      if (mounted) setState(() => _error = exception.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _videoUrl.dispose();
    for (final row in _tiers) {
      for (final field in row.values) {
        field.dispose();
      }
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? type,
    String? hint,
    bool required = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: PrimaryTextField(
      controller: _fields[key]!,
      headerText: label,
      hintText: hint ?? '',
      fieldType: type ?? TextInputType.text,
      maxLines: lines,
      textCapitalization: key == 'name'
          ? TextCapitalization.words
          : TextCapitalization.none,
      required: required,
      optional: optional,
      validator: key == 'name'
          ? (value) => value == null || value.trim().isEmpty
                ? 'Product name is required'
                : null
          : (key == 'homePrice' || key == 'shopPrice')
          ? (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                ? 'Enter a valid price'
                : null
          : null,
    ),
  );

  Widget _fieldLabel(String label, {bool required = false}) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: label),
          if (required)
            TextSpan(
              text: ' *',
              style: style?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: CommonDropdown<T>(
      label: label,
      value: value,
      hint: hint,
      items: items,
      onChanged: onChanged,
      bottomSpacing: 0,
    ),
  );

  Widget _sectionTitle(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _toggleRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        AppToggle(value: value, onChanged: onChanged),
      ],
    ),
  );

  Widget _tierRow(int index) {
    final row = _tiers[index];
    Widget cell(String key, String label, {bool integer = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          PrimaryTextField(
            controller: row[key]!,
            headerText: '',
            hintText: integer ? 'Qty' : 'Rs.',
            fieldType: TextInputType.numberWithOptions(decimal: !integer),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          cell('qty', 'Qty from', integer: true),
          const SizedBox(width: 8),
          cell('homePrice', 'Home price'),
          const SizedBox(width: 8),
          cell('shopPrice', 'Shop price'),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove tier',
            onPressed: () => _removeTier(index),
            icon: const Icon(PhosphorIconsRegular.trash, size: 19),
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final product = widget.product;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            'name',
            'Product name',
            hint: 'e.g. Premium basmati rice',
            required: true,
          ),
          Obx(() {
            final categories = _controller.categories;
            final category = categories.firstWhereOrNull(
              (item) => item.id == _categoryId,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dropdown<String>(
                    label: 'Category',
                    value: categories.any((item) => item.id == _categoryId)
                        ? _categoryId
                        : null,
                    items: categories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    hint: 'Select category',
                    onChanged: (value) => setState(() {
                      _categoryId = value;
                      _subcategory = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown<String>(
                    label: 'Sub-category',
                    value:
                        category?.subcategories.contains(_subcategory) == true
                        ? _subcategory
                        : null,
                    items: (category?.subcategories ?? const <String>[])
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    hint: category == null
                        ? 'Select category first'
                        : 'Optional',
                    onChanged: category == null
                        ? null
                        : (value) => setState(() => _subcategory = value),
                  ),
                ),
              ],
            );
          }),
          _field(
            'sku',
            'SKU / Barcode',
            hint: 'e.g. HRN-0042',
            optional: true,
          ),
          _field(
            'description',
            'Description',
            lines: 3,
            hint: 'Add a short product description',
          ),
          _sectionTitle('Product photos'),
          MultiImageUploader(
            value: _images,
            compact: true,
            onChanged: (value) => setState(() => _images = value),
          ),
          _sectionTitle('Pricing & stock'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'mrp',
                  'MRP',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  hint: 'Rs.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'cost',
                  'Your cost',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  hint: 'Rs.',
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'homePrice',
                  'Home customer price',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  hint: 'Rs.',
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'shopPrice',
                  'Shop owner price',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  hint: 'Rs.',
                  required: true,
                ),
              ),
            ],
          ),
          _field(
            'stock',
            'Total quantity',
            type: TextInputType.number,
            hint: 'Enter available units',
          ),
          _toggleRow(
            title: 'Bulk pricing',
            subtitle: 'Offer a lower price for larger quantities',
            value: _bulkEnabled,
            onChanged: (value) => setState(() => _bulkEnabled = value),
          ),
          if (_bulkEnabled) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < _tiers.length; index++) _tierRow(index),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addTier(),
                icon: const Icon(PhosphorIconsRegular.plus, size: 17),
                label: const Text('Add price tier'),
              ),
            ),
          ],
          _sectionTitle('Video and rating'),
          _fieldLabel('Product video (optional)'),
          const SizedBox(height: 7),
          if (product == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _videoUrl.text.isEmpty
                        ? 'Upload a video from your device'
                        : 'Video uploaded and ready',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _uploadingVideo ? null : _uploadVideo,
                  icon: Icon(
                    _uploadingVideo
                        ? PhosphorIconsRegular.spinnerGap
                        : PhosphorIconsRegular.uploadSimple,
                    size: 17,
                  ),
                  label: Text(
                    _uploadingVideo
                        ? 'Uploading'
                        : _videoUrl.text.isEmpty
                        ? 'Upload video'
                        : 'Replace video',
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: PrimaryTextField(
                    controller: _videoUrl,
                    headerText: '',
                    hintText: 'Paste a video link',
                    fieldType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _uploadingVideo ? null : _uploadVideo,
                  icon: Icon(
                    _uploadingVideo
                        ? PhosphorIconsRegular.spinnerGap
                        : PhosphorIconsRegular.uploadSimple,
                    size: 17,
                  ),
                  label: Text(_uploadingVideo ? 'Uploading' : 'Upload'),
                ),
              ],
            ),
          if (_uploadingVideo) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _videoProgress),
          ],
          if (_videoError != null) ...[
            const SizedBox(height: 6),
            Text(
              _videoError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.star, color: Color(0xFFE9A23B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product == null
                            ? 'No customer ratings yet'
                            : '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} reviews)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Average from customer reviews after delivery. Ratings cannot be edited.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle('Where it shows'),
          _toggleRow(
            title: 'Featured product',
            subtitle: 'Highlight this product in the store',
            value: _featured,
            onChanged: (value) => setState(() => _featured = value),
          ),
          const SizedBox(height: 10),
          _toggleRow(
            title: 'Visible in store',
            subtitle: 'Customers can see and buy this product',
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return SideDrawer(
      title: product == null ? 'Add product' : 'Edit product',
      width: 640,
      body: _buildBody(),
      footer: Row(
        children: [
          if (product != null)
            ConfirmTapButton(
              label: 'Delete',
              confirmLabel: 'Delete product',
              confirmTitle: 'Delete product?',
              confirmMessage:
                  'Products with sales history will be hidden instead of deleted.',
              icon: PhosphorIconsRegular.trash,
              filled: true,
              enabled: !_saving,
              onConfirmed: () {
                _deleteProduct();
              },
            ),
          const Spacer(),
          AppButton(
            label: 'Cancel',
            style: AppButtonStyle.ghost,
            small: true,
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          AppButton(
            label: _saving ? 'Saving…' : 'Save changes',
            icon: const Icon(PhosphorIconsRegular.check, size: 18),
            small: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
