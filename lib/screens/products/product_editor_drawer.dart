import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/product_management_controller.dart';
import '../../models/product_record.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/multi_image_uploader.dart';
import '../../widgets/side_drawer.dart';

/// Star colour is semantic (not part of the brand palette).
const Color _kStar = Color(0xFFE9A23B);

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

  // ---- Theme-driven colours ------------------------------------------------
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  Color get _text => _cs.onSurface;
  Color get _muted =>
      _theme.inputDecorationTheme.labelStyle?.color ?? _cs.onSurfaceVariant;
  Color get _lineColor => _theme.dividerColor;
  Color get _primary => _cs.primary;
  Color get _errorColor => _cs.error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _fields = {
      'name': TextEditingController(text: product?.name ?? ''),
      'sku': TextEditingController(text: product?.sku ?? ''),
      'description': TextEditingController(text: product?.description ?? ''),
      'mrp': TextEditingController(text: _text0(product?.mrp)),
      'cost': TextEditingController(text: _text0(product?.cost)),
      'homePrice': TextEditingController(text: _text0(product?.homePrice)),
      'shopPrice': TextEditingController(text: _text0(product?.shopPrice)),
      'stock': TextEditingController(text: _text0(product?.stock)),
      'ratingAvg': TextEditingController(text: _text0(product?.ratingAvg)),
      'ratingCount': TextEditingController(text: _text0(product?.ratingCount)),
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

  String _text0(num? value) => value == null || value == 0 ? '' : '$value';
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

  // --------------------------------------------------------------------
  // Logic
  // --------------------------------------------------------------------

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
        ratingAvg: _number('ratingAvg').clamp(0, 5).toDouble(),
        ratingCount: _number('ratingCount').toInt(),
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

  // --------------------------------------------------------------------
  // Compact, theme-driven building blocks
  // --------------------------------------------------------------------

  /// Only sizing/hint overrides. Fill, borders, radius and focus colour all
  /// come from the app theme's inputDecorationTheme.
  InputDecoration _decoration({
    String? hint,
    String? prefix,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        color: _muted.withValues(alpha: 0.7),
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      prefixText: prefix,
      prefixStyle: TextStyle(
        color: _muted,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      errorStyle: const TextStyle(fontSize: 11.5, height: 1.2),
    );
  }

  TextStyle get _inputStyle =>
      TextStyle(color: _text, fontSize: 13.5, fontWeight: FontWeight.w500);

  Widget _fieldLabel(String text, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            Text(
              'optional',
              style: TextStyle(
                color: _muted.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _input(
    String key, {
    required String label,
    String? hint,
    String? prefix,
    int lines = 1,
    bool decimal = false,
    bool integer = false,
    bool optional = false,
    String? helper,
    String? Function(String?)? validator,
  }) {
    final numeric = decimal || integer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, optional: optional),
        TextFormField(
          controller: _fields[key],
          minLines: lines,
          maxLines: lines,
          keyboardType: numeric
              ? TextInputType.numberWithOptions(decimal: decimal)
              : (lines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: numeric
              ? [
                  FilteringTextInputFormatter.allow(
                    RegExp(decimal ? r'[0-9.]' : r'[0-9]'),
                  ),
                ]
              : null,
          textCapitalization: key == 'name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          style: _inputStyle,
          cursorColor: _primary,
          decoration: _decoration(hint: hint, prefix: prefix),
          validator:
              validator ??
              (key == 'name'
                  ? (value) => value == null || value.trim().isEmpty
                        ? 'Product name is required'
                        : null
                  : (key == 'homePrice' || key == 'shopPrice')
                  ? (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Enter a valid price'
                        : null
                  : null),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              color: _muted.withValues(alpha: 0.85),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tierInput(
    TextEditingController controller, {
    required String label,
    required String hint,
    String? prefix,
    bool integer = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !integer),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(integer ? r'[0-9]' : r'[0-9.]'),
              ),
            ],
            style: _inputStyle,
            cursorColor: _primary,
            decoration: _decoration(hint: hint, prefix: prefix),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: _cs.surface,
          icon: Icon(PhosphorIconsRegular.caretDown, size: 14, color: _muted),
          style: _inputStyle,
          hint: Text(
            hint ?? '',
            style: TextStyle(
              color: _muted.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
          ),
          decoration: _decoration(),
        ),
      ],
    );
  }

  Widget _row2(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 14),
      Expanded(child: b),
    ],
  );

  /// Section heading with a hairline that runs to the edge.
  Widget _sectionTitle(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: _text,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(height: 1, color: _lineColor)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: _muted.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _toggleRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _muted.withValues(alpha: 0.85),
                      fontSize: 12,
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
  }

  Widget _gap([double h = 14]) => SizedBox(height: h);

  // ---- Category / sub-category matching -----------------------------------
  // Older products may store the category by name (or with different casing),
  // so match by id first, then fall back to the name.

  String _norm(String? value) => (value ?? '').trim().toLowerCase();

  String? _resolveCategoryId(Iterable categories) {
    final current = _categoryId;
    if (current != null && current.isNotEmpty) {
      for (final item in categories) {
        if (item.id == current) return item.id as String;
      }
    }
    final wanted = <String>{
      _norm(current),
      _norm(widget.product?.category),
    }..remove('');
    for (final item in categories) {
      if (wanted.contains(_norm(item.name as String?))) {
        return item.id as String;
      }
    }
    return null;
  }

  /// Sub-category options, always including the product's saved value.
  List<String> _subOptions(List<String> base) {
    final options = [...base];
    final current = _subcategory;
    if (current != null &&
        current.trim().isNotEmpty &&
        !options.any((option) => _norm(option) == _norm(current))) {
      options.add(current);
    }
    return options;
  }

  String? _matchSub(List<String> options) {
    final current = _subcategory;
    if (current == null || current.trim().isEmpty) return null;
    for (final option in options) {
      if (_norm(option) == _norm(current)) return option;
    }
    return null;
  }

  ButtonStyle get _compactOutlined => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  );

  // --------------------------------------------------------------------
  // Sections
  // --------------------------------------------------------------------

  Widget _tierRow(int index) {
    final row = _tiers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _tierInput(row['qty']!, label: 'Qty from', hint: 'Qty', integer: true),
          const SizedBox(width: 10),
          _tierInput(
            row['homePrice']!,
            label: 'Home price',
            hint: '0',
            prefix: 'Rs. ',
          ),
          const SizedBox(width: 10),
          _tierInput(
            row['shopPrice']!,
            label: 'Shop price',
            hint: '0',
            prefix: 'Rs. ',
          ),
          IconButton(
            tooltip: 'Remove tier',
            onPressed: () => _removeTier(index),
            icon: const Icon(PhosphorIconsRegular.trash, size: 18),
            color: _errorColor,
          ),
        ],
      ),
    );
  }

  String? _ratingValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null || number < 0 || number > 5) return 'Enter 0 to 5';
    return null;
  }

  Widget _starRow() {
    return ListenableBuilder(
      listenable: _fields['ratingAvg']!,
      builder: (context, _) {
        final rating = _number('ratingAvg').clamp(0, 5).toDouble();
        return Row(
          children: [
            ...List.generate(5, (i) {
              final filled = rating >= i + 1;
              final half = !filled && rating > i && rating < i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  filled
                      ? PhosphorIconsFill.star
                      : (half
                            ? PhosphorIconsFill.starHalf
                            : PhosphorIconsRegular.star),
                  size: 20,
                  color: (filled || half) ? _kStar : _lineColor,
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(
              rating == 0 ? 'No rating yet' : rating.toStringAsFixed(1),
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _videoButton(bool hasVideo) {
    return OutlinedButton.icon(
      onPressed: _uploadingVideo ? null : _uploadVideo,
      style: _compactOutlined,
      icon: Icon(
        _uploadingVideo
            ? PhosphorIconsRegular.spinnerGap
            : PhosphorIconsRegular.uploadSimple,
        size: 16,
      ),
      label: Text(
        _uploadingVideo
            ? 'Uploading'
            : hasVideo
            ? 'Replace video'
            : 'Upload video',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildBody() {
    final hasVideo = _videoUrl.text.trim().isNotEmpty;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _input('name', label: 'Product name', hint: 'e.g. Basmati rice 5kg'),
          _gap(),
          Obx(() {
            final categories = _controller.categories;
            final resolvedId = _resolveCategoryId(categories);
            if (resolvedId != null && resolvedId != _categoryId) {
              _categoryId = resolvedId;
            }
            final category = categories.firstWhereOrNull(
              (item) => item.id == resolvedId,
            );
            final subOptions = _subOptions(
              category?.subcategories ?? const <String>[],
            );
            return _row2(
              _dropdown<String>(
                label: 'Category',
                value: resolvedId,
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
              _dropdown<String>(
                label: 'Sub-category',
                value: _matchSub(subOptions),
                items: subOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                hint: category == null
                    ? 'Select category first'
                    : 'No sub-category',
                onChanged: category == null
                    ? null
                    : (value) => setState(() => _subcategory = value),
              ),
            );
          }),
          _gap(),
          _input('sku', label: 'SKU or barcode', optional: true),
          _gap(),
          _input(
            'description',
            label: 'Description',
            hint: 'What is it, pack size, brand',
            lines: 3,
            optional: true,
          ),

          _sectionTitle('Photos', subtitle: 'The first photo is the cover. Up to 6 photos.'),
          MultiImageUploader(
            value: _images,
            compact: true,
            onChanged: (value) => setState(() => _images = value),
          ),

          _sectionTitle('Prices'),
          _row2(
            _input(
              'mrp',
              label: 'MRP (printed price)',
              hint: '0',
              prefix: 'Rs. ',
              decimal: true,
              optional: true,
            ),
            _input(
              'cost',
              label: 'Your cost',
              hint: '0',
              prefix: 'Rs. ',
              decimal: true,
              optional: true,
            ),
          ),
          _gap(),
          _row2(
            _input(
              'homePrice',
              label: 'Home customer price',
              hint: '0',
              prefix: 'Rs. ',
              decimal: true,
            ),
            _input(
              'shopPrice',
              label: 'Shop owner price',
              hint: '0',
              prefix: 'Rs. ',
              decimal: true,
            ),
          ),
          _gap(),
          _input(
            'stock',
            label: 'Total quantity in stock',
            hint: '0',
            integer: true,
            helper:
                'Use Add stock on the Inventory page for new purchases so the stock history stays correct.',
          ),

          _sectionTitle('Bulk pricing'),
          _toggleRow(
            'Enable bulk pricing',
            _bulkEnabled,
            (value) => setState(() => _bulkEnabled = value),
            subtitle: 'Offer a lower price for larger quantities',
          ),
          if (_bulkEnabled) ...[
            const SizedBox(height: 10),
            for (var index = 0; index < _tiers.length; index++) _tierRow(index),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addTier(),
                style: _compactOutlined,
                icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                label: const Text(
                  'Add price tier',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],

          _sectionTitle('Video'),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasVideo
                      ? 'Video uploaded and ready'
                      : 'Upload a video from your device',
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
              if (hasVideo && !_uploadingVideo)
                TextButton(
                  onPressed: () => setState(() => _videoUrl.clear()),
                  style: TextButton.styleFrom(foregroundColor: _errorColor),
                  child: const Text('Remove'),
                ),
              _videoButton(hasVideo),
            ],
          ),
          if (_uploadingVideo) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _videoProgress, minHeight: 5),
            ),
          ],
          if (_videoError != null) ...[
            const SizedBox(height: 8),
            Text(
              _videoError!,
              style: TextStyle(color: _errorColor, fontSize: 12),
            ),
          ],

          _sectionTitle('Rating'),
          _starRow(),
          _gap(12),
          _row2(
            _input(
              'ratingAvg',
              label: 'Average rating (0 to 5)',
              hint: 'e.g. 4.5',
              decimal: true,
              validator: _ratingValidator,
            ),
            _input(
              'ratingCount',
              label: 'Number of reviews',
              hint: 'e.g. 120',
              integer: true,
            ),
          ),

          _sectionTitle('Where it shows'),
          _toggleRow(
            'Featured on app home',
            _featured,
            (value) => setState(() => _featured = value),
          ),
          _toggleRow(
            'Visible in app',
            _active,
            (value) => setState(() => _active = value),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _errorColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: _errorColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return SideDrawer(
      title: product == null ? 'Add product' : 'Edit product',
      width: 600,
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
            label: _saving ? 'Saving…' : 'Save',
            icon: const Icon(PhosphorIconsRegular.check, size: 18),
            small: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}