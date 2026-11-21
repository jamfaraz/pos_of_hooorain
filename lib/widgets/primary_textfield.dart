import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shared look for all form fields (desktop / web first).
class _Elite {
  static const double radius = 12;
  static const Duration anim = Duration(milliseconds: 160);

  static InputDecoration decoration(
    BuildContext context, {
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconColor: cs.onSurfaceVariant,
      suffixIconColor: cs.onSurfaceVariant,
      hintStyle: GoogleFonts.inter(
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        fontSize: 13,
      ),
      filled: true,
      fillColor: enabled
          ? cs.surfaceContainerHighest.withValues(alpha: 0.28)
          : cs.surfaceContainerHighest.withValues(alpha: 0.12),
      hoverColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: border(cs.outlineVariant.withValues(alpha: 0.8)),
      disabledBorder: border(cs.outlineVariant.withValues(alpha: 0.4)),
      focusedBorder: border(cs.primary, 1.6),
      errorBorder: border(cs.error),
      focusedErrorBorder: border(cs.error, 1.6),
      errorStyle: TextStyle(color: cs.error, fontSize: 12, height: 1.3),
    );
  }

  /// Small label above the field. Turns primary-colored while focused.
  static Widget label(
    BuildContext context,
    String text, {
    required bool focused,
    bool required = false,
    bool optional = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return AnimatedDefaultTextStyle(
      duration: anim,
      style: base.copyWith(color: focused ? cs.primary : cs.onSurface),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (optional)
              TextSpan(
                text: '  optional',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: cs.error),
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryTextField extends StatefulWidget {
  final TextInputType fieldType;
  final String headerText;
  final String hintText;
  final bool obsecure;
  final bool readOnly;
  final int maxLines;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
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
  final FocusNode? focusNode;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  /// Keeps fields from stretching across huge desktop screens.
  final double maxWidth;

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
    this.onSubmitted,
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
    this.focusNode,
    this.maxLength,
    this.autofillHints,
    this.maxWidth = 560,
  });

  @override
  State<PrimaryTextField> createState() => _PrimaryTextFieldState();
}

class _PrimaryTextFieldState extends State<PrimaryTextField> {
  bool _focused = false;
  bool _hidden = true; // password visibility (web/desktop eye toggle)

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Built-in show/hide toggle for password fields unless a custom suffix is given.
    final Widget? suffix = widget.obsecure && widget.suffixIcon == null
        ? IconButton(
            tooltip: _hidden ? 'Show' : 'Hide',
            splashRadius: 18,
            icon: Icon(
              _hidden
                  ? PhosphorIconsRegular.eye
                  : PhosphorIconsRegular.eyeSlash,
              size: 20,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          )
        : widget.suffixIcon;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focused = v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.headerText.isNotEmpty) ...[
              _Elite.label(
                context,
                widget.headerText,
                focused: _focused,
                required: widget.required,
                optional: widget.optional,
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              obscureText: widget.obsecure && _hidden,
              maxLines: widget.obsecure ? 1 : widget.maxLines,
              maxLength: widget.maxLength,
              keyboardType: widget.fieldType,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              autofillHints: widget.autofillHints,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              validator: widget.validator,
              onChanged: widget.enabled ? widget.onChanged : null,
              onFieldSubmitted: widget.onSubmitted,
              cursorColor: cs.primary,
              cursorWidth: 1.6,
              mouseCursor: widget.readOnly || !widget.enabled
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.text,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: _Elite.decoration(
                context,
                hint: widget.hintText,
                prefixIcon: widget.prefixIcon,
                suffixIcon: suffix,
                helperText: widget.helperText,
                enabled: widget.enabled,
              ).copyWith(counterText: widget.maxLength == null ? null : ''),
            ),
          ],
        ),
      ),
    );
  }
}

class CommonDropdown<T> extends StatefulWidget {
  final String label;
  final List<DropdownMenuItem<T>>? items;
  final T? value;
  final String? hint;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final double bottomSpacing;
  final double maxWidth;

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
    this.maxWidth = 560,
  });

  @override
  State<CommonDropdown<T>> createState() => _CommonDropdownState<T>();
}

class _CommonDropdownState<T> extends State<CommonDropdown<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focused = v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label.isNotEmpty) ...[
              _Elite.label(context, widget.label, focused: _focused),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<T>(
              isExpanded: true,
              initialValue: widget.value,
              items: widget.items,
              onChanged: widget.enabled ? widget.onChanged : null,
              validator: widget.validator,
              decoration: _Elite.decoration(
                context,
                hint: widget.hint,
                enabled: widget.enabled,
              ),
              icon: const Icon(PhosphorIconsRegular.caretDown, size: 18),
              iconEnabledColor: cs.onSurfaceVariant,
              borderRadius: BorderRadius.circular(_Elite.radius),
              dropdownColor: cs.surface,
              focusColor: Colors.transparent,
              menuMaxHeight: 360,
              style: Theme.of(context).textTheme.bodyMedium,
              disabledHint: widget.hint == null ? null : Text(widget.hint!),
            ),
            if (widget.bottomSpacing > 0)
              SizedBox(height: widget.bottomSpacing),
          ],
        ),
      ),
    );
  }
}
