import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import 'gradient_button.dart';

class ToolResultModal {
  ToolResultModal._();

  static void show({
    required BuildContext context,
    required dynamic result,
    required String toolTitle,
    VoidCallback? onDismiss,
  }) {
    String path = '';
    if (result is PdfFileModel) {
      path = result.path;
    } else if (result is File) {
      path = result.path;
    } else if (result is String) {
      path = result;
    }
    showSuccess(
      context: context,
      title: '$toolTitle Successful!',
      filePath: path,
      onDone: onDismiss,
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String title,
    required String filePath,
    String? subtitle,
    bool isPdf = true,
    VoidCallback? onDone,
  }) {
    final file = File(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final fileName = filePath.split(Platform.pathSeparator).last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle ?? '$fileName (${FileUtils.formatBytes(size)})',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (isPdf) ...[
              GradientButton(
                text: 'Preview PDF',
                icon: Icons.visibility_outlined,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(
                        filePath: filePath,
                        title: fileName,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    onPressed: () => ShareService.shareFile(filePath),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open'),
                    onPressed: () => ShareService.openFile(filePath),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (onDone != null) {
                  onDone();
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
