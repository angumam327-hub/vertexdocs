import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';

class PdfOrganizeService {
  static final PdfOrganizeService _instance = PdfOrganizeService._internal();
  factory PdfOrganizeService() => _instance;
  PdfOrganizeService._internal();

  final FileService _fileService = FileService();

  /// Reorganizes PDF: applies custom page order, rotates specific pages, and omits deleted pages
  Future<PdfFileModel> organizePdf({
    required String filePath,
    required List<int> newPageOrder, // 1-based page numbers in desired order
    List<int>? pagesToDelete, // 1-based page numbers to exclude
    Map<int, int>?
        pageRotations, // 1-based page index -> rotation angle (90, 180, 270)
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: bytes);

    final toDelete = pagesToDelete?.toSet() ?? <int>{};
    final effectiveOrder =
        newPageOrder.where((p) => !toDelete.contains(p)).toList();

    if (effectiveOrder.isEmpty) {
      sourceDoc.dispose();
      throw ArgumentError('Cannot organize PDF: All pages have been removed.');
    }

    final outputDoc = PdfDocument();
    outputDoc.pageSettings.margins.all = 0;

    for (final pageNumber in effectiveOrder) {
      final sourceIndex = pageNumber - 1;
      if (sourceIndex >= 0 && sourceIndex < sourceDoc.pages.count) {
        final sourcePage = sourceDoc.pages[sourceIndex];
        outputDoc.pageSettings.size = sourcePage.size;

        final newPage = outputDoc.pages.add();
        final template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

        // Apply rotation if specified for this page
        final angleDeg = pageRotations?[pageNumber] ?? 0;
        if (angleDeg != 0) {
          switch (angleDeg) {
            case 90:
              newPage.rotation = PdfPageRotateAngle.rotateAngle90;
              break;
            case 180:
              newPage.rotation = PdfPageRotateAngle.rotateAngle180;
              break;
            case 270:
              newPage.rotation = PdfPageRotateAngle.rotateAngle270;
              break;
          }
        }
      }
    }

    final totalPages = outputDoc.pages.count;
    sourceDoc.dispose();

    final outputBytes = Uint8List.fromList(outputDoc.saveSync());
    outputDoc.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Organized');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Organized',
      pageCount: totalPages,
    );
  }

  /// Removes specific pages from the PDF document
  Future<PdfFileModel> removePages({
    required String filePath,
    required List<int> pagesToRemove, // 1-based page numbers
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: bytes);

    final removeSet = pagesToRemove.toSet();
    final totalSource = sourceDoc.pages.count;

    if (removeSet.length >= totalSource) {
      sourceDoc.dispose();
      throw ArgumentError('Cannot remove all pages from the document.');
    }

    final outputDoc = PdfDocument();
    outputDoc.pageSettings.margins.all = 0;

    for (int i = 0; i < totalSource; i++) {
      final pageNum = i + 1;
      if (!removeSet.contains(pageNum)) {
        final sourcePage = sourceDoc.pages[i];
        outputDoc.pageSettings.size = sourcePage.size;
        final newPage = outputDoc.pages.add();
        newPage.graphics
            .drawPdfTemplate(sourcePage.createTemplate(), const Offset(0, 0));
      }
    }

    final savedPageCount = outputDoc.pages.count;
    sourceDoc.dispose();

    final outputBytes = Uint8List.fromList(outputDoc.saveSync());
    outputDoc.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Pages_Removed');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'RemovedPages',
      pageCount: savedPageCount,
    );
  }

  /// Extracts chosen pages into either a single consolidated PDF or separate individual files
  Future<List<PdfFileModel>> extractPages({
    required String filePath,
    required List<int> pagesToExtract, // 1-based page numbers
    bool splitIntoSeparateFiles = false,
    String? outputName,
  }) async {
    if (pagesToExtract.isEmpty) {
      throw ArgumentError('Please select at least one page to extract.');
    }

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: bytes);
    final results = <PdfFileModel>[];

    if (!splitIntoSeparateFiles) {
      final outputDoc = PdfDocument();
      outputDoc.pageSettings.margins.all = 0;

      for (final p in pagesToExtract) {
        final idx = p - 1;
        if (idx >= 0 && idx < sourceDoc.pages.count) {
          final sourcePage = sourceDoc.pages[idx];
          outputDoc.pageSettings.size = sourcePage.size;
          final newPage = outputDoc.pages.add();
          newPage.graphics
              .drawPdfTemplate(sourcePage.createTemplate(), const Offset(0, 0));
        }
      }

      final pageCount = outputDoc.pages.count;
      final outputBytes = Uint8List.fromList(outputDoc.saveSync());
      outputDoc.dispose();

      final fileName = outputName?.trim().isNotEmpty == true
          ? outputName!.trim()
          : FileUtils.generateOutputFileName('Extracted_Pages');

      final saved = await _fileService.savePdfBytes(
        outputBytes,
        fileName,
        operationType: 'ExtractedPages',
        pageCount: pageCount,
      );
      results.add(saved);
    } else {
      // Create separate single-page PDF for each extracted page
      for (final p in pagesToExtract) {
        final idx = p - 1;
        if (idx >= 0 && idx < sourceDoc.pages.count) {
          final singleDoc = PdfDocument();
          singleDoc.pageSettings.margins.all = 0;
          final sourcePage = sourceDoc.pages[idx];
          singleDoc.pageSettings.size = sourcePage.size;
          final newPage = singleDoc.pages.add();
          newPage.graphics
              .drawPdfTemplate(sourcePage.createTemplate(), const Offset(0, 0));

          final outBytes = Uint8List.fromList(singleDoc.saveSync());
          singleDoc.dispose();

          final name = FileUtils.generateOutputFileName('Page_$p');
          final saved = await _fileService.savePdfBytes(
            outBytes,
            name,
            operationType: 'ExtractedPages',
            pageCount: 1,
          );
          results.add(saved);
        }
      }
    }

    sourceDoc.dispose();
    return results;
  }

  /// Adds custom page numbers to each page with chosen alignment, format, and font styling
  Future<PdfFileModel> addPageNumbers({
    required String filePath,
    required String
        position, // 'bottom_right', 'bottom_center', 'bottom_left', 'top_right', 'top_center', 'top_left'
    required String
        format, // '{n}', 'Page {n} of {total}', '- {n} -', '{n} / {total}'
    int startNumber = 1,
    double fontSize = 11,
    Color color = const Color(0xFF4A4B57),
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final totalPages = document.pages.count;

    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fontSize,
      style: PdfFontStyle.regular,
    );
    final pdfColor = PdfColor(
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
    );
    final brush = PdfSolidBrush(pdfColor);

    const margin = 36.0; // 0.5 inch margin

    for (int i = 0; i < totalPages; i++) {
      final page = document.pages[i];
      final currentNum = startNumber + i;
      final text = format
          .replaceAll('{n}', '$currentNum')
          .replaceAll('{total}', '$totalPages');

      final textSize = font.measureString(text);
      final pageSize = page.size;

      double x = 0;
      double y = 0;

      if (position.contains('bottom')) {
        y = pageSize.height - margin - textSize.height;
      } else {
        y = margin;
      }

      if (position.contains('right')) {
        x = pageSize.width - margin - textSize.width;
      } else if (position.contains('left')) {
        x = margin;
      } else {
        // center
        x = (pageSize.width - textSize.width) / 2;
      }

      page.graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(x, y, textSize.width, textSize.height),
      );
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Numbered');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Numbered',
      pageCount: totalPages,
    );
  }

  /// Crops page boundaries by trimming top, bottom, left, and right margins
  Future<PdfFileModel> cropPdf({
    required String filePath,
    required double cropTop,
    required double cropBottom,
    required double cropLeft,
    required double cropRight,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: bytes);

    final outputDoc = PdfDocument();
    outputDoc.pageSettings.margins.all = 0;

    for (int i = 0; i < sourceDoc.pages.count; i++) {
      final sourcePage = sourceDoc.pages[i];
      final originalWidth = sourcePage.size.width;
      final originalHeight = sourcePage.size.height;

      final newWidth =
          (originalWidth - (cropLeft + cropRight)).clamp(72.0, originalWidth);
      final newHeight =
          (originalHeight - (cropTop + cropBottom)).clamp(72.0, originalHeight);

      outputDoc.pageSettings.size = Size(newWidth, newHeight);
      final newPage = outputDoc.pages.add();

      final template = sourcePage.createTemplate();
      newPage.graphics.drawPdfTemplate(
        template,
        Offset(-cropLeft, -cropTop),
        Size(originalWidth, originalHeight),
      );
    }

    final pageCount = outputDoc.pages.count;
    sourceDoc.dispose();

    final outputBytes = Uint8List.fromList(outputDoc.saveSync());
    outputDoc.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Cropped');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Cropped',
      pageCount: pageCount,
    );
  }
}
