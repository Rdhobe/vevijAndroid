import 'package:flutter/material.dart';

class ConfirmDialog {
  /// Displays a customizable confirmation dialog.
  /// Parameters:
  /// [title] – dialog title text
  /// [content] – dialog message/description
  /// [showCancel] – whether to show the cancel button (default: true)
  /// [actionText] – text for the main action button (default: "OK")
  /// [onAction] – callback to execute when user confirms
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
    bool showCancel = true,
    String actionText = 'OK',
    required Future<void> Function() onAction,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog first
              await onAction(); // Then execute callback
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
