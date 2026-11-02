import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._();

  /// Shares a single file using system share sheet
  static Future<void> shareFile(
    String filePath, {
    String? subject,
    String? text,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Cannot share non-existent file: $filePath');
        return;
      }
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        subject: subject ?? 'VertexDocs PDF Document',
        text: text,
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }

  /// Shares multiple files at once
  static Future<void> shareMultipleFiles(
    List<String> filePaths, {
    String? subject,
    String? text,
  }) async {
    try {
      final validFiles = <XFile>[];
      for (final path in filePaths) {
        if (await File(path).exists()) {
          validFiles.add(XFile(path));
        }
      }
      if (validFiles.isNotEmpty) {
        await Share.shareXFiles(
          validFiles,
          subject: subject ?? 'VertexDocs Shared Files',
          text: text,
        );
      }
    } catch (e) {
      debugPrint('Error sharing multiple files: $e');
    }
  }

  /// Opens file with the system default viewer or handler
  static Future<OpenResult> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result;
    } catch (e) {
      debugPrint('Error opening file: $e');
      return OpenResult(
        type: ResultType.error,
        message: e.toString(),
      );
    }
  }
}
