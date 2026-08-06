import 'package:flutter/material.dart';

import '../../utils/colors.dart';
import 'feedback_enabled_button.dart';

/// Filled secondary-color action button used across the example app.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Color foreground = outlined ? secondaryColor : Colors.white;
    final Color background = outlined ? Colors.white : secondaryColor;

    return FeedbackEnabledButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: outlined ? secondaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
