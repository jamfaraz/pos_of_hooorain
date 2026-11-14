import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PrimaryTextField extends StatelessWidget {
  final TextInputType fieldType;
  final String headerText;
  final String hintText;
  final bool obsecure;
  final bool readOnly;
  final int maxLines;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool required;
  final bool optional;
  final bool enabled;
  final String? helperText;

  const PrimaryTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.headerText,
    this.fieldType = TextInputType.text,
    this.maxLines = 1,
    this.obsecure = false,
    this.readOnly = false,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerText.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.labelLarge,
              children: [
                TextSpan(text: headerText),
                if (optional)
                  TextSpan(
                    text: ' (optional)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          obscureText: obsecure,
          maxLines: obsecure ? 1 : maxLines,
          keyboardType: fieldType,
          controller: controller,
          readOnly: readOnly,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          enabled: enabled,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            helperText: helperText,
          ),
        ),
      ],
    );
  }
}

class CommonDropdown<T> extends StatelessWidget {
  final String label;
  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final String? hint;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final double bottomSpacing;

  const CommonDropdown({
    super.key,
    required this.label,
    this.items,
    this.value,
    this.hint,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.bottomSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(hintText: hint),
          items: items,
          onChanged: onChanged,
          validator: validator,
          icon: const Icon(PhosphorIconsRegular.caretDown, size: 18),
          menuMaxHeight: 420,
          disabledHint: hint == null ? null : Text(hint!),
        ),
        if (bottomSpacing > 0) SizedBox(height: bottomSpacing),
      ],
    );
  }
}
