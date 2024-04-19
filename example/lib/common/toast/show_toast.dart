
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/colors.dart';
import '../../utils/paddings.dart';

showToast(String message, {Duration? duration}) {
  return Get.snackbar('', message,
      duration: duration ?? const Duration(seconds: 2),
      titleText: const SizedBox(),
      backgroundColor: toastColor,
      snackPosition: SnackPosition.BOTTOM,
      colorText: whiteColor,
      padding: edgeInsetsAllFull,
      margin: edgeInsetsAllFull,
      isDismissible: false);
}
