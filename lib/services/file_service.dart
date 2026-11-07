import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'storage_service.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Prompts user to pick a single PDF file
  Future<File?> pickSinglePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    }
    return null;
  }

  /// Prompts user to pick multiple PDF files
  Future<List<File>> pickMultiplePdfs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result != null) {
        return result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
      }
    } catch (e) {
      debugPrint('Error picking multiple PDFs: $e');
    }
    return [];
  }

  /// Prompts user to pick one or more images
  Future<List<File>> pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        return result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
    return [];
  }

  /// Gets or creates the VertexDocs application storage directory for generated documents
  Future<Directory> getAppPdfDirectory() async {
    Directory baseDir;
    try {
      // Prefer application documents or external storage if available
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = await getTemporaryDirectory();
    }

    final vertexDocsDir =
        Directory('${baseDir.path}${Platform.pathSeparator}VertexDocs');
    if (!await vertexDocsDir.exists()) {
      await vertexDocsDir.create(recursive: true);
    }
    return vertexDocsDir;
  }

  /// Saves PDF bytes to a local file and registers it in storage service
  Future<PdfFileModel> savePdfBytes(
    Uint8List bytes,
    String fileName, {
    String operationType = 'Processed',
    int? pageCount,
    bool isEncrypted = false,
  }) async {
    final dir = await getAppPdfDirectory();
    final sanitized = FileUtils.sanitizeFileName(fileName);
    final finalFileName =
        sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
    final targetPath = '${dir.path}${Platform.pathSeparator}$finalFileName';

    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);

    final model = PdfFileModel(
      id: '${targetPath}_${DateTime.now().millisecondsSinceEpoch}',
      name: finalFileName,
      path: targetPath,
      size: bytes.length,
      pageCount: pageCount,
      lastModified: DateTime.now(),
      operationType: operationType,
      isEncrypted: isEncrypted,
    );

    // Automatically add to recent and saved files
    await StorageService().addRecentFile(model);

    return model;
  }

  /// Saves plain text to a .txt file (e.g. extracted text from OCR)
  Future<File> saveTextFile(String text, String fileName) async {
    final dir = await getAppPdfDirectory();
    final sanitized = FileUtils.sanitizeFileName(fileName);
    final finalFileName =
        sanitized.toLowerCase().endsWith('.txt') ? sanitized : '$sanitized.txt';
    final targetPath = '${dir.path}${Platform.pathSeparator}$finalFileName';

    final file = File(targetPath);
    await file.writeAsString(text, flush: true);
    return file;
  }

  /// Deletes a file from disk and updates storage service
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await StorageService().removeSavedFile(path);
      return true;
    } catch (e) {
      debugPrint('Error deleting file $path: $e');
      return false;
    }
  }

  /// Renames a file on disk and updates storage service
  Future<PdfFileModel?> renameFile(
      String currentPath, String newBaseName) async {
    try {
      final file = File(currentPath);
      if (!await file.exists()) return null;

      final dir = file.parent.path;
      final cleanName = FileUtils.sanitizeFileName(newBaseName);
      final extension = currentPath.split('.').last;
      final newFileName = cleanName.toLowerCase().endsWith('.$extension')
          ? cleanName
          : '$cleanName.$extension';
      final newPath = '$dir${Platform.pathSeparator}$newFileName';

      final renamedFile = await file.rename(newPath);
      final stat = await renamedFile.stat();

      final updatedModel = PdfFileModel(
        id: '${newPath}_${stat.modified.millisecondsSinceEpoch}',
        name: newFileName,
        path: newPath,
        size: stat.size,
        lastModified: stat.modified,
      );

      await StorageService().removeSavedFile(currentPath);
      await StorageService().addSavedFile(updatedModel);
      await StorageService().addRecentFile(updatedModel);

      return updatedModel;
    } catch (e) {
      debugPrint('Error renaming file: $e');
      return null;
    }
  }

  /// Calculates directory size of all VertexDocs saved files
  Future<int> getTotalStorageUsed() async {
    try {
      final dir = await getAppPdfDirectory();
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Clears temporary cache files
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (final f in files) {
          try {
            await f.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Copies a file to the user-accessible Downloads directory
  Future<String?> downloadFileToDevice(String sourcePath) async {
    try {
      final srcFile = File(sourcePath);
      if (!await srcFile.exists()) return null;

      final fileName = srcFile.path.split(Platform.pathSeparator).last;
      Directory? targetDir;

      if (Platform.isAndroid) {
        final dlDir = Directory('/storage/emulated/0/Download');
        if (await dlDir.exists()) {
          targetDir = dlDir;
        } else {
          final extDirs = await getExternalStorageDirectories(
              type: StorageDirectory.downloads);
          if (extDirs != null && extDirs.isNotEmpty) {
            targetDir = extDirs.first;
          } else {
            targetDir = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        targetDir = await getDownloadsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      final destPath = '${targetDir.path}${Platform.pathSeparator}$fileName';
      await srcFile.copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving to downloads: $e');
      return null;
    }
  }
}
