
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  
 final String? text;
 final Function()? onTap;
 final Color? color;
 final Color? containerColor;
  
  const CustomButton(
      {super.key,
      required this.text,
      required this.onTap,
      required this.color,
      required this.containerColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        decoration: BoxDecoration(
          color: containerColor,
        ),
        child: Center(
          child: Text(
            text!,
            style: TextStyle(color: color, fontFamily: 'Poppins', fontSize: 24),
          ),
        ),
      ),
    );
  }
}

