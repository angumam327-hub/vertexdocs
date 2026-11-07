import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import 'file_service.dart';

enum EditorToolType {
  select,
  text,
  replaceText,
  image,
  rectangle,
  circle,
  line,
  highlight,
  pen,
  annotation,
  signature,
  eraser,
}

abstract class EditorElement {
  final String id;
  final int pageIndex; // 0-based
  final EditorToolType type;

  EditorElement({
    required this.id,
    required this.pageIndex,
    required this.type,
  });

  EditorElement copy();
}

class TextEditorElement extends EditorElement {
  String text;
  Offset position; // In PDF point coordinates
  Size size;
  double fontSize;
  String fontFamily; // 'Helvetica', 'Courier', 'Times'
  Color color;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  TextAlign alignment;
  double opacity;
  Color? backgroundColor;

  TextEditorElement({
    required super.id,
    required super.pageIndex,
    required this.text,
    required this.position,
    this.size = const Size(180, 40),
    this.fontSize = 14.0,
    this.fontFamily = 'Helvetica',
    this.color = Colors.black,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.alignment = TextAlign.left,
    this.opacity = 1.0,
    this.backgroundColor,
  }) : super(type: EditorToolType.text);

  @override
  TextEditorElement copy() => TextEditorElement(
        id: id,
        pageIndex: pageIndex,
        text: text,
        position: position,
        size: size,
        fontSize: fontSize,
        fontFamily: fontFamily,
        color: color,
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        alignment: alignment,
        opacity: opacity,
        backgroundColor: backgroundColor,
      );
}

class ReplaceTextEditorElement extends EditorElement {
  Rect originalBounds;
  String newText;
  double fontSize;
  Color color;
  bool isBold;

  ReplaceTextEditorElement({
    required super.id,
    required super.pageIndex,
    required this.originalBounds,
    required this.newText,
    this.fontSize = 13.0,
    this.color = Colors.black,
    this.isBold = false,
  }) : super(type: EditorToolType.replaceText);

  @override
  ReplaceTextEditorElement copy() => ReplaceTextEditorElement(
        id: id,
        pageIndex: pageIndex,
        originalBounds: originalBounds,
        newText: newText,
        fontSize: fontSize,
        color: color,
        isBold: isBold,
      );
}

class ShapeEditorElement extends EditorElement {
  Rect bounds;
  Color strokeColor;
  Color? fillColor;
  double strokeWidth;
  double opacity;

  ShapeEditorElement({
    required super.id,
    required super.pageIndex,
    required super.type,
    required this.bounds,
    this.strokeColor = const Color(0xFFF23882),
    this.fillColor,
    this.strokeWidth = 2.0,
    this.opacity = 1.0,
  });

  @override
  ShapeEditorElement copy() => ShapeEditorElement(
        id: id,
        pageIndex: pageIndex,
        type: type,
        bounds: bounds,
        strokeColor: strokeColor,
        fillColor: fillColor,
        strokeWidth: strokeWidth,
        opacity: opacity,
      );
}

class AnnotationEditorElement extends EditorElement {
  Offset position;
  String noteText;
  Color color;
  double opacity;

  AnnotationEditorElement({
    required super.id,
    required super.pageIndex,
    required this.position,
    required this.noteText,
    this.color = const Color(0xFFFFEB3B), // Note yellow
    this.opacity = 0.95,
  }) : super(type: EditorToolType.annotation);

  @override
  AnnotationEditorElement copy() => AnnotationEditorElement(
        id: id,
        pageIndex: pageIndex,
        position: position,
        noteText: noteText,
        color: color,
        opacity: opacity,
      );
}

class LineEditorElement extends EditorElement {
  Offset start;
  Offset end;
  Color color;
  double strokeWidth;

  LineEditorElement({
    required super.id,
    required super.pageIndex,
    required this.start,
    required this.end,
    this.color = const Color(0xFFF23882),
    this.strokeWidth = 2.0,
  }) : super(type: EditorToolType.line);

  @override
  LineEditorElement copy() => LineEditorElement(
        id: id,
        pageIndex: pageIndex,
        start: start,
        end: end,
        color: color,
        strokeWidth: strokeWidth,
      );
}

class HighlightEditorElement extends EditorElement {
  Rect bounds;
  Color highlightColor;

  HighlightEditorElement({
    required super.id,
    required super.pageIndex,
    required this.bounds,
    this.highlightColor = const Color(0xFFFFEB3B), // Yellow highlight
  }) : super(type: EditorToolType.highlight);

  @override
  HighlightEditorElement copy() => HighlightEditorElement(
        id: id,
        pageIndex: pageIndex,
        bounds: bounds,
        highlightColor: highlightColor,
      );
}

class DrawingEditorElement extends EditorElement {
  List<Offset> points;
  Color color;
  double strokeWidth;

  DrawingEditorElement({
    required super.id,
    required super.pageIndex,
    required this.points,
    this.color = const Color(0xFFF23882),
    this.strokeWidth = 3.0,
  }) : super(type: EditorToolType.pen);

  @override
  DrawingEditorElement copy() => DrawingEditorElement(
        id: id,
        pageIndex: pageIndex,
        points: List<Offset>.from(points),
        color: color,
        strokeWidth: strokeWidth,
      );
}

class ImageEditorElement extends EditorElement {
  Uint8List imageBytes;
  Rect bounds;
  int rotationDegrees;

  ImageEditorElement({
    required super.id,
    required super.pageIndex,
    required this.imageBytes,
    required this.bounds,
    this.rotationDegrees = 0,
    super.type = EditorToolType.image,
  });

  @override
  ImageEditorElement copy() => ImageEditorElement(
        id: id,
        pageIndex: pageIndex,
        imageBytes: imageBytes,
        bounds: bounds,
        rotationDegrees: rotationDegrees,
        type: type,
      );
}

class RenderedPdfPage {
  final int pageNumber; // 1-based
  final Size size;
  final Uint8List imageBytes;

  const RenderedPdfPage({
    required this.pageNumber,
    required this.size,
    required this.imageBytes,
  });
}

class PdfEditorService {
  static final PdfEditorService _instance = PdfEditorService._internal();
  factory PdfEditorService() => _instance;
  PdfEditorService._internal();

  final FileService _fileService = FileService();

  /// Rasterizes all pages of the PDF to high-res images to guarantee 100% faithful original layout
  Future<List<RenderedPdfPage>> loadAndRenderPages(
    String filePath, {
    void Function(double, String)? onProgress,
  }) async {
    final pdfDoc = await pdfx.PdfDocument.openFile(filePath);
    final List<RenderedPdfPage> pages = [];

    for (int i = 1; i <= pdfDoc.pagesCount; i++) {
      onProgress?.call(i / pdfDoc.pagesCount,
          'Rendering page $i of ${pdfDoc.pagesCount}...');
      final page = await pdfDoc.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      pages.add(
        RenderedPdfPage(
          pageNumber: i,
          size: Size(page.width, page.height),
          imageBytes: rendered?.bytes ?? Uint8List(0),
        ),
      );
      await page.close();
    }

    await pdfDoc.close();
    return pages;
  }

  /// Get total page count of a PDF file
  Future<int> getPdfPageCount(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (_) {
      try {
        final pdfDoc = await pdfx.PdfDocument.openFile(filePath);
        final count = pdfDoc.pagesCount;
        await pdfDoc.close();
        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Render a single page by 1-based page number
  Future<RenderedPdfPage?> renderSinglePage(
      String filePath, int pageNumber) async {
    try {
      final pdfDoc = await pdfx.PdfDocument.openFile(filePath);
      if (pageNumber < 1 || pageNumber > pdfDoc.pagesCount) {
        await pdfDoc.close();
        return null;
      }
      final page = await pdfDoc.getPage(pageNumber);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      final renderedPage = RenderedPdfPage(
        pageNumber: pageNumber,
        size: Size(page.width, page.height),
        imageBytes: rendered?.bytes ?? Uint8List(0),
      );
      await page.close();
      await pdfDoc.close();
      return renderedPage;
    } catch (_) {
      // Fallback for environments without native PDF rasterizer (e.g. unit/widget test runners)
      try {
        final bytes = await File(filePath).readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        if (pageNumber < 1 || pageNumber > doc.pages.count) {
          doc.dispose();
          return null;
        }
        final pageSize = doc.pages[pageNumber - 1].size;
        doc.dispose();
        return RenderedPdfPage(
          pageNumber: pageNumber,
          size: Size(pageSize.width, pageSize.height),
          imageBytes: Uint8List(0),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Extracts text lines from PDF page for tap-to-edit capabilities
  Future<List<({String text, Rect bounds})>> extractPageTextLines(
      String filePath, int pageIndex) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final textLines = extractor.extractTextLines(
          startPageIndex: pageIndex, endPageIndex: pageIndex);
      final List<({String text, Rect bounds})> results = [];

      for (final line in textLines) {
        if (line.text.trim().isNotEmpty) {
          results.add((text: line.text, bounds: line.bounds));
        }
      }
      document.dispose();
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Burns all overlay elements, page order, and rotations onto original PDF and saves as a new PDF document
  Future<PdfFileModel> saveEditedPdf({
    required String originalPdfPath,
    required List<EditorElement> elements,
    List<int>? pageOrder,
    Map<int, int>? pageRotations,
    String? outputName,
  }) async {
    final originalBytes = await File(originalPdfPath).readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: originalBytes);
    final outputDoc = PdfDocument();
    outputDoc.pageSettings.margins.all = 0;

    final targetOrder =
        pageOrder ?? List.generate(sourceDoc.pages.count, (i) => i);

    for (int newPageIndex = 0;
        newPageIndex < targetOrder.length;
        newPageIndex++) {
      final origIdx = targetOrder[newPageIndex];
      if (origIdx < 0 || origIdx >= sourceDoc.pages.count) continue;
      final srcPage = sourceDoc.pages[origIdx];
      outputDoc.pageSettings.size = srcPage.size;
      final newPage = outputDoc.pages.add();

      // Apply rotation if any
      final rot = (pageRotations?[origIdx] ?? 0) % 360;
      if (rot == 90) newPage.rotation = PdfPageRotateAngle.rotateAngle90;
      if (rot == 180) newPage.rotation = PdfPageRotateAngle.rotateAngle180;
      if (rot == 270) newPage.rotation = PdfPageRotateAngle.rotateAngle270;

      // Draw original page vector template
      newPage.graphics
          .drawPdfTemplate(srcPage.createTemplate(), const Offset(0, 0));

      // Draw all elements belonging to this page
      final pageElements =
          elements.where((e) => e.pageIndex == newPageIndex).toList();
      _renderElementsOnPage(newPage, pageElements);
    }

    final outputBytes = Uint8List.fromList(outputDoc.saveSync());
    final pageCount = outputDoc.pages.count;
    outputDoc.dispose();
    sourceDoc.dispose();

    final rawName = originalPdfPath
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.pdf', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : 'Edited_${rawName}_$timestamp.pdf';

    return await _fileService.savePdfBytes(
      outputBytes,
      finalName,
      operationType: 'Edited PDF',
      pageCount: pageCount,
    );
  }

  void _renderElementsOnPage(PdfPage page, List<EditorElement> elements) {
    final graphics = page.graphics;
    for (final elem in elements) {
      if (elem is ReplaceTextEditorElement) {
        // Redact original background with white box
        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
          bounds: elem.originalBounds,
        );

        // Draw new text if not blank (if blank, acts as a pure redaction/erasure)
        if (elem.newText.trim().isNotEmpty) {
          final font = PdfStandardFont(
            PdfFontFamily.helvetica,
            elem.fontSize,
            style: elem.isBold ? PdfFontStyle.bold : PdfFontStyle.regular,
          );
          graphics.drawString(
            elem.newText,
            font,
            brush: PdfSolidBrush(PdfColor(
              (elem.color.r * 255).round(),
              (elem.color.g * 255).round(),
              (elem.color.b * 255).round(),
            )),
            bounds: elem.originalBounds,
          );
        }
      } else if (elem is TextEditorElement) {
        graphics.save();
        if (elem.opacity < 1.0) {
          graphics.setTransparency(elem.opacity);
        }

        if (elem.backgroundColor != null) {
          graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(
              (elem.backgroundColor!.r * 255).round(),
              (elem.backgroundColor!.g * 255).round(),
              (elem.backgroundColor!.b * 255).round(),
            )),
            bounds: Rect.fromLTWH(
              elem.position.dx,
              elem.position.dy,
              elem.size.width,
              elem.size.height,
            ),
          );
        }

        PdfFontFamily pFontFamily = PdfFontFamily.helvetica;
        if (elem.fontFamily.toLowerCase() == 'courier') {
          pFontFamily = PdfFontFamily.courier;
        } else if (elem.fontFamily.toLowerCase().contains('times')) {
          pFontFamily = PdfFontFamily.timesRoman;
        }

        PdfFontStyle style = PdfFontStyle.regular;
        if (elem.isBold && elem.isItalic) {
          style = PdfFontStyle.bold;
        } else if (elem.isBold) {
          style = PdfFontStyle.bold;
        } else if (elem.isItalic) {
          style = PdfFontStyle.italic;
        }

        final font = PdfStandardFont(pFontFamily, elem.fontSize, style: style);
        final brush = PdfSolidBrush(PdfColor(
          (elem.color.r * 255).round(),
          (elem.color.g * 255).round(),
          (elem.color.b * 255).round(),
        ));

        final format = PdfStringFormat();
        if (elem.alignment == TextAlign.center) {
          format.alignment = PdfTextAlignment.center;
        } else if (elem.alignment == TextAlign.right) {
          format.alignment = PdfTextAlignment.right;
        } else if (elem.alignment == TextAlign.justify) {
          format.alignment = PdfTextAlignment.justify;
        } else {
          format.alignment = PdfTextAlignment.left;
        }

        final measured = font.measureString(elem.text);
        final exportWidth = max(elem.size.width, measured.width + 12);
        final exportHeight = max(elem.size.height, measured.height + 6);

        graphics.drawString(
          elem.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            elem.position.dx,
            elem.position.dy,
            exportWidth,
            exportHeight,
          ),
          format: format,
        );

        if (elem.isUnderline) {
          final fontWidth = font.measureString(elem.text).width;
          final underlineY = elem.position.dy + font.height + 1;
          graphics.drawLine(
            PdfPen(brush.color, width: 1.2),
            Offset(elem.position.dx, underlineY),
            Offset(elem.position.dx + fontWidth, underlineY),
          );
        }
        graphics.restore();
      } else if (elem is ShapeEditorElement) {
        graphics.save();
        if (elem.opacity < 1.0) {
          graphics.setTransparency(elem.opacity);
        }

        final strokeColor = PdfColor(
          (elem.strokeColor.r * 255).round(),
          (elem.strokeColor.g * 255).round(),
          (elem.strokeColor.b * 255).round(),
        );
        final pen = PdfPen(strokeColor, width: elem.strokeWidth);
        PdfBrush? brush;
        if (elem.fillColor != null) {
          brush = PdfSolidBrush(PdfColor(
            (elem.fillColor!.r * 255).round(),
            (elem.fillColor!.g * 255).round(),
            (elem.fillColor!.b * 255).round(),
          ));
        }

        if (elem.type == EditorToolType.circle) {
          graphics.drawEllipse(elem.bounds, pen: pen, brush: brush);
        } else {
          graphics.drawRectangle(pen: pen, brush: brush, bounds: elem.bounds);
        }
        graphics.restore();
      } else if (elem is AnnotationEditorElement) {
        graphics.save();
        if (elem.opacity < 1.0) {
          graphics.setTransparency(elem.opacity);
        }

        // Draw note background with pink accent border
        final noteRect =
            Rect.fromLTWH(elem.position.dx, elem.position.dy, 120, 50);
        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(
            (elem.color.r * 255).round(),
            (elem.color.g * 255).round(),
            (elem.color.b * 255).round(),
          )),
          pen: PdfPen(PdfColor(242, 56, 130), width: 1.5),
          bounds: noteRect,
        );

        final noteFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          9,
          style: PdfFontStyle.regular,
        );
        graphics.drawString(
          elem.noteText,
          noteFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(
            elem.position.dx + 4,
            elem.position.dy + 4,
            112,
            42,
          ),
        );
        graphics.restore();
      } else if (elem is LineEditorElement) {
        final pen = PdfPen(
          PdfColor(
            (elem.color.r * 255).round(),
            (elem.color.g * 255).round(),
            (elem.color.b * 255).round(),
          ),
          width: elem.strokeWidth,
        );
        graphics.drawLine(pen, elem.start, elem.end);
      } else if (elem is HighlightEditorElement) {
        graphics.save();
        graphics.setTransparency(0.40);
        final brush = PdfSolidBrush(PdfColor(
          (elem.highlightColor.r * 255).round(),
          (elem.highlightColor.g * 255).round(),
          (elem.highlightColor.b * 255).round(),
        ));
        graphics.drawRectangle(brush: brush, bounds: elem.bounds);
        graphics.restore();
      } else if (elem is DrawingEditorElement) {
        if (elem.points.length > 1) {
          final pen = PdfPen(
            PdfColor(
              (elem.color.r * 255).round(),
              (elem.color.g * 255).round(),
              (elem.color.b * 255).round(),
            ),
            width: elem.strokeWidth,
          );
          pen.lineCap = PdfLineCap.round;
          pen.lineJoin = PdfLineJoin.round;
          for (int i = 0; i < elem.points.length - 1; i++) {
            graphics.drawLine(pen, elem.points[i], elem.points[i + 1]);
          }
        } else if (elem.points.length == 1) {
          final brush = PdfSolidBrush(PdfColor(
            (elem.color.r * 255).round(),
            (elem.color.g * 255).round(),
            (elem.color.b * 255).round(),
          ));
          graphics.drawEllipse(
            Rect.fromCircle(
              center: elem.points.first,
              radius: elem.strokeWidth / 2,
            ),
            brush: brush,
          );
        }
      } else if (elem is ImageEditorElement) {
        final bitmap = PdfBitmap(elem.imageBytes);
        if (elem.rotationDegrees % 360 != 0) {
          graphics.save();
          graphics.translateTransform(
              elem.bounds.center.dx, elem.bounds.center.dy);
          graphics.rotateTransform(elem.rotationDegrees.toDouble());
          graphics.drawImage(
            bitmap,
            Rect.fromCenter(
              center: Offset.zero,
              width: elem.bounds.width,
              height: elem.bounds.height,
            ),
          );
          graphics.restore();
        } else {
          graphics.drawImage(bitmap, elem.bounds);
        }
      }
    }
  }
}
