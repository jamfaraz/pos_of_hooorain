import 'package:flutter/material.dart';

import '../../controllers/inventory_controller.dart';
import '../../models/product_record.dart';
import '../../widgets/app_button.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/side_drawer.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class StockInDrawer extends StatefulWidget {
  const StockInDrawer({
    required this.controller,
    required this.products,
    super.key,
  });

  final InventoryController controller;
  final List<ProductRecord> products;

  @override
  State<StockInDrawer> createState() => _StockInDrawerState();
}

class _StockInDrawerState extends State<StockInDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  String? _productId;
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SideDrawer(
    title: 'Add stock',
    subtitle: 'Record a purchase and increase available inventory.',
    body: Form(
      key: _formKey,
      child: Column(
        children: [
          CommonDropdown<String>(
            label: 'Product',
            hint: 'Select product',
            value: _productId,
            bottomSpacing: 0,
            items: widget.products
                .map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
                )
                .toList(),
            validator: (value) => value == null ? 'Select a product' : null,
            onChanged: (value) => setState(() => _productId = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantity,
            decoration: const InputDecoration(labelText: 'Quantity purchased'),
            keyboardType: TextInputType.number,
            validator: (value) {
              final quantity = int.tryParse(value ?? '');
              return quantity == null || quantity <= 0
                  ? 'Enter a quantity greater than zero'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 3,
          ),
        ],
      ),
    ),
    footer: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: _saving ? 'Saving…' : 'Add stock',
          onPressed: _saving ? null : _submit,
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final product = widget.controller.productById(_productId);
    if (product == null) {
      MessageToast.showSuccess(
        msg: 'Refresh inventory and retry.',
        title: 'Product unavailable',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.addStock(
        product: product,
        quantity: int.parse(_quantity.text),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      MessageToast.showSuccess(
        msg: '${product.name} inventory was updated.',
        title: 'Stock added',
      );
    } catch (exception) {
      MessageToast.showError(
        msg: exception.toString(),
        title: 'Could not add stock',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
