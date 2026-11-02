import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';

class PdfInfo {
  final int pageCount;
  final int sizeInBytes;
  final bool isEncrypted;
  final String title;

  const PdfInfo({
    required this.pageCount,
    required this.sizeInBytes,
    required this.isEncrypted,
    required this.title,
  });
}

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final FileService _fileService = FileService();

  /// Reads PDF metadata (page count, encrypted status, file size)
  Future<PdfInfo> getPdfInfo(String filePath, {String? password}) async {
    final file = File(filePath);
    final size = await file.length();
    final name = file.path.split(Platform.pathSeparator).last;

    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document;
      if (password != null && password.isNotEmpty) {
        document = PdfDocument(inputBytes: bytes, password: password);
      } else {
        document = PdfDocument(inputBytes: bytes);
      }

      final pageCount = document.pages.count;
      final isEncrypted = document.security.userPassword.isNotEmpty;
      document.dispose();

      return PdfInfo(
        pageCount: pageCount,
        sizeInBytes: size,
        isEncrypted: isEncrypted,
        title: name,
      );
    } catch (e) {
      // If failed due to password protection
      final isLocked = e.toString().toLowerCase().contains('password') ||
          e.toString().toLowerCase().contains('encrypted') ||
          e.toString().toLowerCase().contains('security');
      return PdfInfo(
        pageCount: 0,
        sizeInBytes: size,
        isEncrypted: isLocked,
        title: name,
      );
    }
  }

  /// Merges multiple PDF files into one in the specified order
  Future<PdfFileModel> mergePdfs({
    required List<String> filePaths,
    String? outputName,
  }) async {
    if (filePaths.isEmpty) {
      throw ArgumentError('At least one PDF file is required to merge.');
    }

    final outputDocument = PdfDocument();
    outputDocument.pageSettings.margins.all = 0;

    int totalPages = 0;

    for (final path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final sourceDocument = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < sourceDocument.pages.count; i++) {
        final sourcePage = sourceDocument.pages[i];
        outputDocument.pageSettings.size = sourcePage.size;
        final newPage = outputDocument.pages.add();
        final template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        totalPages++;
      }
      sourceDocument.dispose();
    }

    final bytes = Uint8List.fromList(outputDocument.saveSync());
    outputDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Merged_Document');

    return await _fileService.savePdfBytes(
      bytes,
      fileName,
      operationType: 'Merged',
      pageCount: totalPages,
    );
  }

  /// Extracts a range of pages from startPage to endPage (1-based index)
  Future<PdfFileModel> splitPdf({
    required String filePath,
    required int startPage,
    required int endPage,
    String? outputName,
    String? password,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final sourceDocument = password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    final totalPages = sourceDocument.pages.count;
    if (startPage < 1 || endPage > totalPages || startPage > endPage) {
      sourceDocument.dispose();
      throw ArgumentError(
        'Invalid page range $startPage to $endPage. Document has $totalPages pages.',
      );
    }

    final outputDocument = PdfDocument();
    outputDocument.pageSettings.margins.all = 0;

    for (int i = startPage - 1; i < endPage; i++) {
      final sourcePage = sourceDocument.pages[i];
      outputDocument.pageSettings.size = sourcePage.size;
      final newPage = outputDocument.pages.add();
      final template = sourcePage.createTemplate();
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
    }

    sourceDocument.dispose();

    final outputBytes = Uint8List.fromList(outputDocument.saveSync());
    outputDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Split_p${startPage}_p$endPage');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Split',
      pageCount: endPage - startPage + 1,
    );
  }

  /// Rotates pages in a PDF document by 90, 180, or 270 degrees
  Future<PdfFileModel> rotatePdf({
    required String filePath,
    required int degrees, // 90, 180, 270
    List<int>? targetPages, // 1-based, null = all pages
    String? outputName,
    String? password,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final document = password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    final PdfPageRotateAngle angle;
    switch (degrees) {
      case 90:
        angle = PdfPageRotateAngle.rotateAngle90;
        break;
      case 180:
        angle = PdfPageRotateAngle.rotateAngle180;
        break;
      case 270:
        angle = PdfPageRotateAngle.rotateAngle270;
        break;
      default:
        angle = PdfPageRotateAngle.rotateAngle0;
    }

    for (int i = 0; i < document.pages.count; i++) {
      final pageNumber = i + 1;
      if (targetPages == null || targetPages.contains(pageNumber)) {
        document.pages[i].rotation = angle;
      }
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Rotated_${degrees}deg');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Rotated',
      pageCount: pageCount,
    );
  }

  /// Adds a custom text watermark to each page of the document
  Future<PdfFileModel> addWatermark({
    required String filePath,
    required String watermarkText,
    double opacity = 0.35,
    double fontSize = 42,
    Color color = const Color(0xFFF23882),
    bool isDiagonal = true,
    String? outputName,
    String? password,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final document = password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fontSize,
      style: PdfFontStyle.bold,
    );
    final pdfColor = PdfColor(
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
    );
    final brush = PdfSolidBrush(pdfColor);

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final graphics = page.graphics;
      final size = page.size;

      graphics.save();
      graphics.setTransparency(opacity);

      final textSize = font.measureString(watermarkText);

      if (isDiagonal) {
        graphics.translateTransform(size.width / 2, size.height / 2);
        graphics.rotateTransform(-45);
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );
      } else {
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            (size.width - textSize.width) / 2,
            (size.height - textSize.height) / 2,
            textSize.width,
            textSize.height,
          ),
        );
      }

      graphics.restore();
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Watermarked');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Watermarked',
      pageCount: pageCount,
    );
  }

  /// Encrypts and password-protects a PDF with AES-256
  Future<PdfFileModel> protectPdf({
    required String filePath,
    required String userPassword,
    String? ownerPassword,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final document = PdfDocument(inputBytes: bytes);

    // Apply AES-256 encryption
    final security = document.security;
    security.userPassword = userPassword;
    security.ownerPassword = (ownerPassword != null && ownerPassword.isNotEmpty)
        ? ownerPassword
        : userPassword;
    security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
    security.permissions.addAll([
      PdfPermissionsFlags.print,
      PdfPermissionsFlags.copyContent,
    ]);

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Protected');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Protected',
      pageCount: pageCount,
      isEncrypted: true,
    );
  }

  /// Unlocks an encrypted PDF with valid password and saves an unencrypted copy
  Future<PdfFileModel> unlockPdf({
    required String filePath,
    required String password,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Open with user password
    final sourceDocument = PdfDocument(inputBytes: bytes, password: password);

    // Copy pages into clean unencrypted document
    final unencryptedDocument = PdfDocument();
    unencryptedDocument.pageSettings.margins.all = 0;

    for (int i = 0; i < sourceDocument.pages.count; i++) {
      final sourcePage = sourceDocument.pages[i];
      unencryptedDocument.pageSettings.size = sourcePage.size;
      final newPage = unencryptedDocument.pages.add();
      final template = sourcePage.createTemplate();
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
    }

    final pageCount = sourceDocument.pages.count;
    sourceDocument.dispose();

    final outputBytes = Uint8List.fromList(unencryptedDocument.saveSync());
    unencryptedDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Unlocked');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Unlocked',
      pageCount: pageCount,
      isEncrypted: false,
    );
  }

  /// Compresses PDF using maximum flate compression and stream optimization
  Future<PdfFileModel> compressPdf({
    required String filePath,
    int qualityLevel = 1, // 0 = Extreme, 1 = Recommended, 2 = Low
    String? outputName,
    String? password,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final document = password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    // Set best compression level on the document
    document.compressionLevel = PdfCompressionLevel.best;

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Compressed');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Compressed',
      pageCount: pageCount,
    );
  }

  /// Converts a list of image files into a single PDF document
  Future<PdfFileModel> imagesToPdf({
    required List<String> imagePaths,
    String? outputName,
    bool fitToPage = true,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('At least one image is required.');
    }

    final document = PdfDocument();
    document.pageSettings.margins.all = 0;

    for (final path in imagePaths) {
      final imgFile = File(path);
      if (!await imgFile.exists()) continue;

      final imgBytes = await imgFile.readAsBytes();
      final pdfBitmap = PdfBitmap(imgBytes);

      // Match page size to image aspect ratio or standard A4
      final width = pdfBitmap.width.toDouble();
      final height = pdfBitmap.height.toDouble();

      document.pageSettings.size = Size(width, height);
      final page = document.pages.add();

      page.graphics.drawImage(
        pdfBitmap,
        Rect.fromLTWH(0, 0, width, height),
      );
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Images_Doc');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'ImagesToPdf',
      pageCount: pageCount,
    );
  }

  /// Converts PDF pages into images using pdfx
  Future<List<String>> pdfToImages({
    required String filePath,
    pdfx.PdfPageImageFormat format = pdfx.PdfPageImageFormat.png,
    double scale = 2.0,
    String? password,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(filePath, password: password);
    final outputDir = await _fileService.getAppPdfDirectory();
    final baseName =
        filePath.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

    final resultPaths = <String>[];
    final ext = format == pdfx.PdfPageImageFormat.png ? 'png' : 'jpg';

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: format,
      );
      await page.close();

      if (rendered != null && rendered.bytes.isNotEmpty) {
        final imgPath =
            '${outputDir.path}${Platform.pathSeparator}${baseName}_page_$i.$ext';
        final file = File(imgPath);
        await file.writeAsBytes(rendered.bytes);
        resultPaths.add(imgPath);
      }
    }

    await doc.close();
    return resultPaths;
  }

  /// Extracts plain text from all pages of a PDF document
  Future<String> extractText({
    required String filePath,
    String? password,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final document = password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      final pageText =
          extractor.extractText(startPageIndex: i, endPageIndex: i);
      buffer.writeln('--- Page ${i + 1} ---');
      buffer.writeln(pageText.trim());
      buffer.writeln();
    }

    document.dispose();
    return buffer.toString().trim();
  }
}
