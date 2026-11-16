import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium animated toggle used across the whole app.
///
/// Same API as before (`value`, `onChanged`, `label`), so existing screens
/// upgrade automatically. All colours come from the app theme.
///
/// * Gradient track with a soft glow when on
/// * Thumb that stretches while pressed and glides with an eased animation
/// * Animated check icon inside the thumb
/// * Hover halo, keyboard focus ring (Space / Enter), drag-to-toggle
/// * Light haptic tick on change, dimmed when disabled
///
/// [label] is used for accessibility. Set [showLabel] to also draw it
/// beside the toggle.
class AppToggle extends StatefulWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    this.label,
    this.showLabel = false,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool showLabel;

  @override
  State<AppToggle> createState() => _AppToggleState();
}

class _AppToggleState extends State<AppToggle> {
  static const double _trackWidth = 42;
  static const double _trackHeight = 22;
  static const double _pad = 3;
  static const double _thumbHeight = _trackHeight - _pad * 2;
  static const double _thumbWidth = _thumbHeight;
  static const double _thumbWidthPressed = 20;

  bool _hovering = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  void _toggle() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onChanged!(!widget.value);
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final on = widget.value;

    // Off track: the app's line colour nudged toward its subtext colour.
    final subtext =
        theme.inputDecorationTheme.labelStyle?.color ??
        theme.colorScheme.onSurfaceVariant;
    final offColor = Color.lerp(theme.dividerColor, subtext, 0.45)!;

    final thumbWidth = _pressed && _enabled ? _thumbWidthPressed : _thumbWidth;
    final thumbLeft = on ? _trackWidth - _pad - thumbWidth : _pad;
    const duration = Duration(milliseconds: 260);
    const curve = Curves.easeOutCubic;

    final toggle = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowHoverHighlight: (value) => setState(() => _hovering = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _toggle();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onHorizontalDragStart: (_) => _setPressed(true),
        onHorizontalDragEnd: (_) => _setPressed(false),
        onHorizontalDragCancel: () => _setPressed(false),
        onHorizontalDragUpdate: (details) {
          if (!_enabled) return;
          if (details.delta.dx > 1 && !on) _toggle();
          if (details.delta.dx < -1 && on) _toggle();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            width: _trackWidth,
            height: _trackHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: on ? [primary, primary] : [offColor, offColor],
              ),
              boxShadow: [
                if (on && _enabled)
                  BoxShadow(
                    color: primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                if (_focused)
                  BoxShadow(
                    color: primary.withValues(alpha: 0.28),
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Hover halo that follows the thumb.
                AnimatedPositioned(
                  duration: duration,
                  curve: curve,
                  left: thumbLeft - 5,
                  top: (_trackHeight - 26) / 2,
                  width: thumbWidth + 10,
                  height: 26,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: (primary).withValues(
                          alpha: _enabled && (_hovering || _pressed)
                              ? (on ? 0.14 : 0.08)
                              : 0,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb.
                AnimatedPositioned(
                  duration: duration,
                  curve: curve,
                  left: thumbLeft,
                  top: _pad,
                  width: thumbWidth,
                  height: _thumbHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_thumbHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: on
                            ? Icon(
                                Icons.check_rounded,
                                key: const ValueKey('on'),
                                size: 10,
                                color: primary,
                              )
                            : const SizedBox.shrink(key: ValueKey('off')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final labelText = widget.label;
    final hasLabel = labelText != null && labelText.isNotEmpty;

    return Semantics(
      label: labelText,
      toggled: on,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: widget.showLabel && hasLabel
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    labelText,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 10),
                ExcludeSemantics(child: toggle),
              ],
            )
          : ExcludeSemantics(child: toggle),
    );
  }
}
