import 'package:flutter/material.dart';

/// Tap scale/translation feedback wrapper. Press animation state is owned by
/// this widget — callers should not mutate scale/translation from outside.
class FeedbackEnabledButton extends StatefulWidget {
  const FeedbackEnabledButton({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<FeedbackEnabledButton> createState() => _FeedbackEnabledButtonState();
}

class _FeedbackEnabledButtonState extends State<FeedbackEnabledButton> {
  double _scale = 1.0;
  double _translationX = 0.0;

  void _setPressed(bool pressed) {
    setState(() {
      _scale = pressed ? 0.95 : 1.0;
      _translationX = pressed ? 0.025 : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(_scale, _scale, 1.0)
          ..translate(_translationX * 274.69, 0.0),
        child: widget.child,
      ),
    );
  }
}
