import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';

class PdfSecurityService {
  static final PdfSecurityService _instance = PdfSecurityService._internal();
  factory PdfSecurityService() => _instance;
  PdfSecurityService._internal();

  final FileService _fileService = FileService();

  /// Stamps electronic signature onto chosen PDF page at exact coordinates
  Future<PdfFileModel> signPdf({
    required String filePath,
    required Uint8List signatureBytes,
    required int pageNumber, // 1-based
    required Offset position,
    required Size signatureSize,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    if (pageNumber < 1 || pageNumber > document.pages.count) {
      document.dispose();
      throw ArgumentError(
          'Invalid page number $pageNumber for document with ${document.pages.count} pages.');
    }

    final page = document.pages[pageNumber - 1];
    final bitmap = PdfBitmap(signatureBytes);

    // Draw signature
    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(
          position.dx, position.dy, signatureSize.width, signatureSize.height),
    );

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Signed');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Signed',
      pageCount: pageCount,
    );
  }

  /// Permanently purges and redacts sensitive keywords or custom rectangle regions from document
  Future<PdfFileModel> redactPdf({
    required String filePath,
    required List<String> keywordsToRedact,
    List<Rect>? customRects,
    int? targetPageNumber, // 1-based, null = all pages
    String redactionText = '[REDACTED]',
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final blackBrush = PdfSolidBrush(PdfColor(20, 20, 25));
    final whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));
    final labelFont =
        PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);

    // Use PdfTextLine extraction to find bounds of words to redact
    final extractor = PdfTextExtractor(document);

    for (int i = 0; i < document.pages.count; i++) {
      final pageIndex = i;
      final pageNum = i + 1;
      if (targetPageNumber != null && targetPageNumber != pageNum) continue;

      final page = document.pages[pageIndex];
      final textLines = extractor.extractTextLines(
          startPageIndex: pageIndex, endPageIndex: pageIndex);

      for (final line in textLines) {
        for (final word in line.wordCollection) {
          final wordText = word.text.toLowerCase().trim();
          for (final keyword in keywordsToRedact) {
            final cleanKey = keyword.toLowerCase().trim();
            if (cleanKey.isNotEmpty && wordText.contains(cleanKey)) {
              // Draw solid black redaction block
              final rect = word.bounds;
              page.graphics.drawRectangle(
                brush: blackBrush,
                bounds: Rect.fromLTWH(rect.left - 2, rect.top - 1,
                    rect.width + 4, rect.height + 2),
              );

              // Draw white redaction label
              if (rect.width > 30) {
                page.graphics.drawString(
                  redactionText,
                  labelFont,
                  brush: whiteBrush,
                  bounds: Rect.fromLTWH(
                      rect.left, rect.top + 1, rect.width, rect.height),
                );
              }
            }
          }
        }
      }

      // Draw custom manual redaction rectangles if provided
      if (customRects != null) {
        for (final rect in customRects) {
          page.graphics.drawRectangle(
            brush: blackBrush,
            bounds: rect,
          );
          page.graphics.drawString(
            redactionText,
            labelFont,
            brush: whiteBrush,
            bounds: Rect.fromLTWH(
                rect.left + 4, rect.top + 4, rect.width - 8, rect.height - 8),
          );
        }
      }
    }

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Redacted');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Redacted',
      pageCount: pageCount,
    );
  }
}
