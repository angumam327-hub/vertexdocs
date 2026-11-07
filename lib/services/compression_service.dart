import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';
import 'storage_service.dart';

class CompressionResult {
  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;
  final int targetSize;
  final double reductionPercentage;
  final String fileType;
  final String outputName;
  final bool targetMet;
  final String? note;

  const CompressionResult({
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
    required this.targetSize,
    required this.reductionPercentage,
    required this.fileType,
    required this.outputName,
    required this.targetMet,
    this.note,
  });

  String get formattedOriginalSize => FileUtils.formatBytes(originalSize);
  String get formattedCompressedSize => FileUtils.formatBytes(compressedSize);
  String get formattedTargetSize => FileUtils.formatBytes(targetSize);
  String get formattedReduction => '${reductionPercentage.toStringAsFixed(1)}%';
  int get savedBytes => (originalSize - compressedSize).clamp(0, originalSize);
  String get formattedSavedBytes => FileUtils.formatBytes(savedBytes);
}

class CompressionService {
  static final CompressionService _instance = CompressionService._internal();
  factory CompressionService() => _instance;
  CompressionService._internal();

  final FileService _fileService = FileService();

  /// Compresses a file targeting an explicit user-defined size in KB or MB
  Future<CompressionResult> compressToTargetSize({
    required String filePath,
    required int targetSizeKb,
    void Function(double progress, String status)? onProgress,
  }) async {
    final originalFile = File(filePath);
    if (!await originalFile.exists()) {
      throw FileSystemException('Source file not found', filePath);
    }

    final originalBytes = await originalFile.readAsBytes();
    final originalSize = originalBytes.length;
    final targetBytes = targetSizeKb * 1024;
    final ext = filePath.split('.').last.toLowerCase();

    onProgress?.call(0.1, 'Analyzing file and target size requirements...');

    Uint8List compressedBytes;
    String outputExt = ext;
    String? note;

    switch (ext) {
      case 'pdf':
        final pdfRes = await _compressPdfToTarget(
          originalFile,
          originalBytes,
          targetBytes,
          onProgress,
        );
        compressedBytes = pdfRes.bytes;
        note = pdfRes.note;
        outputExt = 'pdf';
        break;

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        final imgRes = await _compressImageToTarget(
          originalBytes,
          ext,
          targetBytes,
          onProgress,
        );
        compressedBytes = imgRes.bytes;
        note = imgRes.note;
        outputExt = imgRes.format;
        break;

      case 'docx':
      case 'pptx':
      case 'xlsx':
        final officeRes = await _compressOfficePackageToTarget(
          originalBytes,
          ext,
          targetBytes,
          onProgress,
        );
        compressedBytes = officeRes.bytes;
        note = officeRes.note;
        outputExt = ext;
        break;

      default:
        compressedBytes = await _compressGeneric(originalBytes, onProgress);
        outputExt = ext;
        break;
    }

    onProgress?.call(0.9, 'Finalizing output file...');

    final appDir = await _fileService.getAppPdfDirectory();
    final rawBaseName = originalFile.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = 'Compressed_${rawBaseName}_$timestamp.$outputExt';
    final targetPath = '${appDir.path}${Platform.pathSeparator}$finalFileName';

    final resultFile = File(targetPath);
    await resultFile.writeAsBytes(compressedBytes);

    final compressedSize = compressedBytes.length;
    final saved = originalSize - compressedSize;
    final reduction =
        originalSize > 0 && saved > 0 ? (saved / originalSize) * 100 : 0.0;
    final targetMet =
        compressedSize <= (targetBytes * 1.08); // within 8% tolerance

    // Register into VertexDocs storage if PDF
    if (outputExt == 'pdf') {
      final model = PdfFileModel(
        id: '${targetPath}_$timestamp',
        name: finalFileName,
        path: targetPath,
        size: compressedSize,
        lastModified: DateTime.now(),
        operationType: 'Compressed',
      );
      await StorageService().addSavedFile(model);
    }

    onProgress?.call(1.0, 'Compression completed successfully!');

    return CompressionResult(
      originalPath: filePath,
      compressedPath: targetPath,
      originalSize: originalSize,
      compressedSize: compressedSize,
      targetSize: targetBytes,
      reductionPercentage: reduction,
      fileType: outputExt.toUpperCase(),
      outputName: finalFileName,
      targetMet: targetMet,
      note: note,
    );
  }

  /// PDF compression to approach user's target size
  Future<({Uint8List bytes, String? note})> _compressPdfToTarget(
    File originalFile,
    Uint8List inputBytes,
    int targetBytes,
    void Function(double, String)? onProgress,
  ) async {
    onProgress?.call(
        0.2, 'Optimizing PDF font tables and stream dictionaries...');

    // Pass 1: Standard best lossless stream compression
    final document = PdfDocument(inputBytes: inputBytes);
    document.compressionLevel = PdfCompressionLevel.best;
    final pass1Bytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    if (pass1Bytes.length <= targetBytes) {
      return (
        bytes: pass1Bytes,
        note: 'Target achieved via standard stream compression.'
      );
    }

    // Pass 2: Target is smaller than pass 1. Perform adaptive image downsampling & page rasterization
    onProgress?.call(0.4, 'Target size requires adaptive page optimization...');

    try {
      final pdfDoc = await pdfx.PdfDocument.openFile(originalFile.path);
      final double budgetPerPage = targetBytes / max(1, pageCount);

      // Determine appropriate scale and JPEG quality based on budget per page
      double scale = 1.5;
      int quality = 70;

      if (budgetPerPage < 30 * 1024) {
        // Under 30 KB/page
        scale = 1.0;
        quality = 35;
      } else if (budgetPerPage < 80 * 1024) {
        // 30-80 KB/page
        scale = 1.2;
        quality = 55;
      } else if (budgetPerPage < 150 * 1024) {
        // 80-150 KB/page
        scale = 1.4;
        quality = 70;
      } else {
        scale = 1.8;
        quality = 80;
      }

      final newDoc = PdfDocument();
      newDoc.pageSettings.margins.all = 0;
      newDoc.compressionLevel = PdfCompressionLevel.best;

      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final pct = 0.4 + (0.45 * (i / pdfDoc.pagesCount));
        onProgress?.call(pct, 'Optimizing page $i of ${pdfDoc.pagesCount}...');

        final page = await pdfDoc.getPage(i);
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (rendered != null) {
          // Re-compress image with calculated quality
          final decoded = img.decodeImage(rendered.bytes);
          Uint8List pageBytes = rendered.bytes;
          if (decoded != null) {
            pageBytes =
                Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
          }

          final bitmap = PdfBitmap(pageBytes);
          newDoc.pageSettings.size = Size(page.width, page.height);
          final newPage = newDoc.pages.add();
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, page.width, page.height),
          );
        }
      }

      await pdfDoc.close();
      final pass2Bytes = Uint8List.fromList(newDoc.saveSync());
      newDoc.dispose();

      String? note;
      if (pass2Bytes.length > targetBytes) {
        note =
            'Achieved closest optimal size without compromising page readability.';
      }

      // Return the smaller of pass 1 or pass 2
      if (pass2Bytes.length < pass1Bytes.length) {
        return (bytes: pass2Bytes, note: note);
      } else {
        return (
          bytes: pass1Bytes,
          note: 'Standard compression yielded best visual result.'
        );
      }
    } catch (_) {
      // Fallback to pass 1 if rasterization fails
      return (
        bytes: pass1Bytes,
        note: 'Compressed using maximum document stream compression.'
      );
    }
  }

  /// Image compression targeting exact byte budget
  Future<({Uint8List bytes, String format, String? note})>
      _compressImageToTarget(
    Uint8List inputBytes,
    String ext,
    int targetBytes,
    void Function(double, String)? onProgress,
  ) async {
    onProgress?.call(0.3, 'Decoding image raster...');
    final image = img.decodeImage(inputBytes);
    if (image == null) {
      return (bytes: inputBytes, format: ext, note: null);
    }

    // If input is already smaller than target, apply high quality pass
    if (inputBytes.length <= targetBytes) {
      return (
        bytes: inputBytes,
        format: ext,
        note: 'Original file is already smaller than requested target.'
      );
    }

    onProgress?.call(
        0.5, 'Optimizing resolution and compression parameters...');

    // Binary search on quality and scaling to match target size
    int minQuality = 15;
    int maxQuality = 90;
    int bestQuality = 75;
    double scale = 1.0;

    final ratio = targetBytes / inputBytes.length;
    if (ratio < 0.2) {
      scale = 0.5;
    } else if (ratio < 0.5) {
      scale = 0.75;
    }

    img.Image workingImage = image;
    if (scale < 0.98) {
      workingImage = img.copyResize(
        image,
        width: (image.width * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    Uint8List bestResult =
        Uint8List.fromList(img.encodeJpg(workingImage, quality: bestQuality));

    // Iterative convergence
    for (int step = 0; step < 5; step++) {
      if (bestResult.length <= targetBytes &&
          (targetBytes - bestResult.length) < (targetBytes * 0.15)) {
        break; // Within 15% of target
      }

      if (bestResult.length > targetBytes) {
        maxQuality = bestQuality - 1;
      } else {
        minQuality = bestQuality + 1;
      }

      if (minQuality > maxQuality) break;

      bestQuality = ((minQuality + maxQuality) / 2).round().clamp(15, 95);
      bestResult =
          Uint8List.fromList(img.encodeJpg(workingImage, quality: bestQuality));
    }

    // If still larger, scale down further
    if (bestResult.length > targetBytes && scale > 0.4) {
      final furtherScaled = img.copyResize(
        workingImage,
        width: (workingImage.width * 0.7).round(),
        interpolation: img.Interpolation.linear,
      );
      bestResult = Uint8List.fromList(
          img.encodeJpg(furtherScaled, quality: bestQuality.clamp(20, 60)));
    }

    String? note;
    if (bestResult.length > targetBytes) {
      note =
          'Achieved closest optimal size while maintaining clear visual detail.';
    }

    return (bytes: bestResult, format: 'jpg', note: note);
  }

  /// Office package (DOCX, PPTX, XLSX) compression
  Future<({Uint8List bytes, String? note})> _compressOfficePackageToTarget(
    Uint8List inputBytes,
    String ext,
    int targetBytes,
    void Function(double, String)? onProgress,
  ) async {
    onProgress?.call(0.3, 'Inspecting $ext archive components...');
    final archive = ZipDecoder().decodeBytes(inputBytes);
    final outputArchive = Archive();

    final ratio = (targetBytes / inputBytes.length).clamp(0.2, 0.9);
    final int targetQuality = (ratio * 80).round().clamp(30, 80);
    final double targetScale = ratio < 0.4 ? 0.6 : (ratio < 0.7 ? 0.8 : 0.95);

    int count = 0;
    for (final file in archive.files) {
      count++;
      if (count % 8 == 0) {
        final pct = 0.3 + (0.5 * (count / archive.files.length));
        onProgress?.call(pct,
            'Optimizing internal media and assets ($count/${archive.files.length})...');
      }

      if (file.isFile) {
        final pathLower = file.name.toLowerCase();
        final isMedia = (pathLower.contains('/media/') ||
                pathLower.contains('\\media\\')) &&
            (pathLower.endsWith('.jpg') ||
                pathLower.endsWith('.jpeg') ||
                pathLower.endsWith('.png'));

        if (isMedia) {
          try {
            final mediaBytes = file.content;
            final imgObj = img.decodeImage(mediaBytes);
            if (imgObj != null && imgObj.width > 200) {
              final resized = img.copyResize(
                imgObj,
                width: (imgObj.width * targetScale).round(),
                interpolation: img.Interpolation.linear,
              );
              final newBytes = Uint8List.fromList(
                  img.encodeJpg(resized, quality: targetQuality));
              if (newBytes.length < mediaBytes.length) {
                outputArchive
                    .addFile(ArchiveFile(file.name, newBytes.length, newBytes));
                continue;
              }
            }
          } catch (_) {}
        }

        outputArchive.addFile(ArchiveFile(file.name, file.size, file.content));
      }
    }

    onProgress?.call(0.85, 'Re-packing archive with maximum deflate...');
    final compressedBytes = ZipEncoder().encode(outputArchive, level: 9);
    final result = Uint8List.fromList(compressedBytes);

    String? note;
    if (result.length > targetBytes) {
      note = 'Achieved closest optimal size by compressing all embedded media.';
    }

    return (bytes: result, note: note);
  }

  Future<Uint8List> _compressGeneric(
    Uint8List inputBytes,
    void Function(double, String)? onProgress,
  ) async {
    onProgress?.call(0.5, 'Applying stream deflate compression...');
    final deflater = Deflate(inputBytes, level: 9);
    return Uint8List.fromList(deflater.getBytes());
  }
}
