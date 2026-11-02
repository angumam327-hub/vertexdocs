import 'dart:math';
import 'package:intl/intl.dart';

class FileUtils {
  FileUtils._();

  /// Formats byte count to human readable string (B, KB, MB, GB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
  }

  /// Formats file size in bytes to readable string (alias for formatBytes)
  static String formatFileSize(int bytes, [int decimals = 1]) =>
      formatBytes(bytes, decimals);

  /// Extracts the file name from a path
  static String getFileName(String path) {
    if (path.isEmpty) return '';
    final separator = path.contains('/') ? '/' : '\\';
    return path.split(separator).last;
  }

  /// Formats DateTime to readable string e.g. "Oct 24, 2026"
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Formats DateTime with time e.g. "Oct 24, 2026 • 10:30 AM"
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  /// Sanitizes file names to remove illegal characters
  static String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Checks if file path ends with .pdf
  static bool isPdf(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  /// Checks if file path ends with supported image extension
  static bool isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  /// Generates a unique timestamped file name
  static String generateOutputFileName(String prefix, [String ext = 'pdf']) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final cleanPrefix = sanitizeFileName(prefix);
    return '${cleanPrefix}_$timestamp.$ext';
  }
}
