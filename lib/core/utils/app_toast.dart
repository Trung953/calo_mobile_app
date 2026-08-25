import 'package:flutter/material.dart';

class AppToast {
  // Bỏ hoàn toàn thông báo thành công
  static void showSuccess(BuildContext context, String message, {String? title}) {
    // Không làm gì cả để loại bỏ toàn bộ popup/toast thành công
  }

  static void showError(BuildContext context, dynamic error, {String? title}) {
    if (!context.mounted) return;

    String errorMsg = error.toString();
    if (errorMsg.startsWith('Exception: ')) {
      errorMsg = errorMsg.replaceFirst('Exception: ', '');
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEF4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorMsg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}