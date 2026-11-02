import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';

class FormFieldInfo {
  final String name;
  final String type; // 'text', 'checkbox', 'radio', 'combo', 'list', 'unknown'
  final String value;
  final bool isChecked;

  const FormFieldInfo({
    required this.name,
    required this.type,
    required this.value,
    this.isChecked = false,
  });
}

class PdfEditService {
  static final PdfEditService _instance = PdfEditService._internal();
  factory PdfEditService() => _instance;
  PdfEditService._internal();

  final FileService _fileService = FileService();

  /// Adds custom styled text to a specific page
  Future<PdfFileModel> addText({
    required String filePath,
    required int pageNumber, // 1-based
    required String text,
    required Offset position,
    double fontSize = 14,
    Color color = Colors.black,
    bool isBold = false,
    bool isItalic = false,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final pageIndex = (pageNumber - 1).clamp(0, document.pages.count - 1);
    final page = document.pages[pageIndex];

    final style = isBold && isItalic
        ? PdfFontStyle.bold
        : isBold
            ? PdfFontStyle.bold
            : isItalic
                ? PdfFontStyle.italic
                : PdfFontStyle.regular;

    final font =
        PdfStandardFont(PdfFontFamily.helvetica, fontSize, style: style);
    final brush = PdfSolidBrush(
      PdfColor(
        (color.r * 255.0).round().clamp(0, 255),
        (color.g * 255.0).round().clamp(0, 255),
        (color.b * 255.0).round().clamp(0, 255),
      ),
    );

    page.graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(
          position.dx, position.dy, page.size.width - position.dx - 20, 0),
    );

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Edited_Text');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Edited',
      pageCount: pageCount,
    );
  }

  /// Adds an image or stamp onto a specific page
  Future<PdfFileModel> addImage({
    required String filePath,
    required int pageNumber,
    required Uint8List imageBytes,
    required Offset position,
    required Size size,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final pageIndex = (pageNumber - 1).clamp(0, document.pages.count - 1);
    final page = document.pages[pageIndex];
    final bitmap = PdfBitmap(imageBytes);

    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
    );

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Edited_Image');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Edited',
      pageCount: pageCount,
    );
  }

  /// Draws vector shapes (Rectangle, Circle, Line, Arrow) on the PDF page
  Future<PdfFileModel> addShape({
    required String filePath,
    required int pageNumber,
    required String shapeType, // 'rectangle', 'circle', 'line', 'arrow'
    required Rect bounds,
    Color strokeColor = const Color(0xFFF23882),
    Color? fillColor,
    double strokeWidth = 2.0,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final pageIndex = (pageNumber - 1).clamp(0, document.pages.count - 1);
    final page = document.pages[pageIndex];

    final pen = PdfPen(
      PdfColor(
        (strokeColor.r * 255.0).round().clamp(0, 255),
        (strokeColor.g * 255.0).round().clamp(0, 255),
        (strokeColor.b * 255.0).round().clamp(0, 255),
      ),
      width: strokeWidth,
    );

    PdfBrush? brush;
    if (fillColor != null) {
      brush = PdfSolidBrush(
        PdfColor(
          (fillColor.r * 255.0).round().clamp(0, 255),
          (fillColor.g * 255.0).round().clamp(0, 255),
          (fillColor.b * 255.0).round().clamp(0, 255),
        ),
      );
    }

    switch (shapeType) {
      case 'rectangle':
        page.graphics.drawRectangle(
          pen: pen,
          brush: brush,
          bounds: bounds,
        );
        break;
      case 'circle':
        page.graphics.drawEllipse(
          bounds,
          pen: pen,
          brush: brush,
        );
        break;
      case 'line':
        page.graphics.drawLine(
          pen,
          Offset(bounds.left, bounds.top),
          Offset(bounds.right, bounds.bottom),
        );
        break;
      case 'arrow':
        // Draw line with arrowhead
        final start = Offset(bounds.left, bounds.top);
        final end = Offset(bounds.right, bounds.bottom);
        page.graphics.drawLine(pen, start, end);

        final angle = atan2(end.dy - start.dy, end.dx - start.dx);
        const arrowLength = 14.0;
        const arrowAngle = pi / 6;

        final p1 = Offset(
          end.dx - arrowLength * cos(angle - arrowAngle),
          end.dy - arrowLength * sin(angle - arrowAngle),
        );
        final p2 = Offset(
          end.dx - arrowLength * cos(angle + arrowAngle),
          end.dy - arrowLength * sin(angle + arrowAngle),
        );

        page.graphics.drawLine(pen, end, p1);
        page.graphics.drawLine(pen, end, p2);
        break;
    }

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Edited_Shape');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Edited',
      pageCount: pageCount,
    );
  }

  /// Adds highlight, underline, strikeout, or sticky note annotations
  Future<PdfFileModel> addAnnotation({
    required String filePath,
    required int pageNumber,
    required String
        annotationType, // 'highlight', 'underline', 'strikeout', 'note'
    required Rect bounds,
    String? noteText,
    Color color = const Color(0xFFFFEB3B),
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final pageIndex = (pageNumber - 1).clamp(0, document.pages.count - 1);
    final page = document.pages[pageIndex];

    final graphics = page.graphics;
    graphics.save();

    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    if (annotationType == 'highlight') {
      graphics.setTransparency(0.4);
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(r, g, b)),
        bounds: bounds,
      );
    } else if (annotationType == 'underline') {
      final pen = PdfPen(PdfColor(r, g, b), width: 2.0);
      graphics.drawLine(pen, Offset(bounds.left, bounds.bottom),
          Offset(bounds.right, bounds.bottom));
    } else if (annotationType == 'strikeout') {
      final pen = PdfPen(PdfColor(r, g, b), width: 1.5);
      final midY = (bounds.top + bounds.bottom) / 2;
      graphics.drawLine(
          pen, Offset(bounds.left, midY), Offset(bounds.right, midY));
    } else if (annotationType == 'note') {
      // Draw sticky note icon & text box
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(254, 240, 138)),
        pen: PdfPen(PdfColor(234, 179, 8), width: 1.0),
        bounds: bounds,
      );
      if (noteText != null && noteText.isNotEmpty) {
        final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
        graphics.drawString(
          noteText,
          font,
          brush: PdfSolidBrush(PdfColor(30, 30, 30)),
          bounds: Rect.fromLTWH(bounds.left + 4, bounds.top + 4,
              bounds.width - 8, bounds.height - 8),
        );
      }
    }

    graphics.restore();

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Annotated');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'Annotated',
      pageCount: pageCount,
    );
  }

  /// Inspects interactive AcroForm fields present in PDF
  Future<List<FormFieldInfo>> getFormFields(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final fields = <FormFieldInfo>[];
    if (document.form.fields.count > 0) {
      for (int i = 0; i < document.form.fields.count; i++) {
        final field = document.form.fields[i];
        final name = field.name ?? 'Field_$i';

        if (field is PdfTextBoxField) {
          fields.add(FormFieldInfo(
            name: name,
            type: 'text',
            value: field.text,
          ));
        } else if (field is PdfCheckBoxField) {
          fields.add(FormFieldInfo(
            name: name,
            type: 'checkbox',
            value: field.isChecked ? 'true' : 'false',
            isChecked: field.isChecked,
          ));
        } else {
          fields.add(FormFieldInfo(
            name: name,
            type: 'unknown',
            value: '',
          ));
        }
      }
    }

    document.dispose();
    return fields;
  }

  /// Fills AcroForm field values and saves completed PDF
  Future<PdfFileModel> fillFormFields({
    required String filePath,
    required Map<String, dynamic> fieldValues,
    bool flattenForm = false,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    if (document.form.fields.count > 0) {
      for (int i = 0; i < document.form.fields.count; i++) {
        final field = document.form.fields[i];
        final name = field.name ?? '';
        if (fieldValues.containsKey(name)) {
          final val = fieldValues[name];
          if (field is PdfTextBoxField) {
            field.text = val?.toString() ?? '';
          } else if (field is PdfCheckBoxField) {
            field.isChecked = val == true || val == 'true';
          }
        }
      }

      if (flattenForm) {
        document.form.flattenAllFields();
      }
    }

    final pageCount = document.pages.count;
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Form_Filled');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'FormFilled',
      pageCount: pageCount,
    );
  }
}
