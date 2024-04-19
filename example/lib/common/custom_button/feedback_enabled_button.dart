import 'package:flutter/material.dart';

class FeedbackEnabledButton extends StatefulWidget {

   double scaleFactor;
   double translationFactorX;
   Function()? onTap;
   Widget childWidget;


   FeedbackEnabledButton({
    required this.scaleFactor,
    required this.translationFactorX,
    this.onTap,
    required this.childWidget,
    Key? key}) : super(key: key);

  @override
  State<FeedbackEnabledButton> createState() => _FeedbackEnabledButtonState();
}

class _FeedbackEnabledButtonState extends State<FeedbackEnabledButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: (_) {
          // Shrink the button towards the center on tap
          setState(() {
            widget.scaleFactor = 0.95;
            widget.translationFactorX = 0.025; // Adjust this value to control the centerward shrink
          });
        },
        onTapUp: (_) {
          // Restore the button to its original size on release
          setState(() {
            widget.scaleFactor = 1.0;
            widget.translationFactorX = 0.0;
          });
        },
        onTapCancel: () {
          // Restore the button to its original size if the tap is canceled
          setState(() {
            widget.scaleFactor = 1.0;
            widget.translationFactorX = 0.0;
          });
        },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(
          widget.scaleFactor,
          widget.scaleFactor,
          1.0,
        )..translate( widget.translationFactorX * 274.69, 0.0),
        child: widget.childWidget,
      )

    );
  }
}
