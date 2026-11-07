import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertexdocs/models/user_profile_model.dart';
import 'package:vertexdocs/services/compression_service.dart';
import 'package:vertexdocs/services/document_editor_service.dart';
import 'package:vertexdocs/services/pdf_editor_service.dart';
import 'package:vertexdocs/services/translation_service.dart';

void main() {
  group('Feature 2: Profile Management & Avatar Tests', () {
    test('UserProfileModel default values and initials', () {
      const model =
          UserProfileModel(name: 'John Doe', email: 'john@example.com');
      expect(model.name, 'John Doe');
      expect(model.email, 'john@example.com');
      expect(model.initials, 'JD');

      const singleName = UserProfileModel(name: 'VertexDocs');
      expect(singleName.initials, 'V');
    });

    test('UserProfileModel copyWith and JSON serialization', () {
      final now = DateTime.now();
      final model = UserProfileModel(
        name: 'Alice Smith',
        email: 'alice@example.com',
        phone: '+1234567890',
        bio: 'Mobile Developer',
        photoPath: '/path/to/avatar.jpg',
        updatedAt: now,
      );

      final json = model.toJson();
      expect(json['name'], 'Alice Smith');
      expect(json['email'], 'alice@example.com');

      final deserialized = UserProfileModel.fromJson(json);
      expect(deserialized.name, 'Alice Smith');
      expect(deserialized.email, 'alice@example.com');
      expect(deserialized.photoPath, '/path/to/avatar.jpg');

      final updated = model.copyWith(clearPhoto: true, name: 'Alice Doe');
      expect(updated.name, 'Alice Doe');
      expect(updated.photoPath, null);
    });
  });

  group('Feature 1: Multi-Language Translation Tests', () {
    test('Supported languages catalog contains 35+ global languages', () {
      expect(TranslationService.supportedLanguages.length,
          greaterThanOrEqualTo(35));
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'en'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'ta'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'hi'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'es'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'fr'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'de'),
          isTrue);
      expect(TranslationService.supportedLanguages.any((l) => l.code == 'ar'),
          isTrue);
    });

    test('Resolves correct language display names', () {
      final en = TranslationService.supportedLanguages
          .firstWhere((l) => l.code == 'en');
      final ta = TranslationService.supportedLanguages
          .firstWhere((l) => l.code == 'ta');
      final hi = TranslationService.supportedLanguages
          .firstWhere((l) => l.code == 'hi');

      expect(en.name, 'English');
      expect(ta.name, 'Tamil');
      expect(hi.name, 'Hindi');
    });
  });

  group('Feature 3: Smart File Compressor Tests', () {
    test(
        'CompressionResult calculates metrics correctly with custom target size',
        () {
      const result = CompressionResult(
        originalPath: '/path/doc.pdf',
        compressedPath: '/path/compressed_doc.pdf',
        originalSize: 1048576, // 1 MB
        compressedSize: 419430, // ~410 KB
        targetSize: 512000, // 500 KB target
        reductionPercentage: 60.0,
        fileType: 'PDF',
        outputName: 'compressed_doc.pdf',
        targetMet: true,
      );

      expect(result.reductionPercentage, 60.0);
      expect(result.formattedReduction, '60.0%');
      expect(result.savedBytes, 1048576 - 419430);
      expect(result.formattedOriginalSize.contains('MB'), isTrue);
      expect(result.targetMet, isTrue);
      expect(result.formattedTargetSize.contains('KB'), isTrue);
    });
  });

  group('Feature 4: Document Editor A4 Tests', () {
    test('DocParagraphItem structure, heading styles and formatting', () {
      final p = DocParagraphItem(
        id: 'p_1',
        text: 'VertexDocs high performance text processing.',
        isBold: true,
        fontSize: 16.0,
        alignment: TextAlign.center,
        headingStyle: 'heading1',
      );

      expect(p.text, 'VertexDocs high performance text processing.');
      expect(p.isBold, isTrue);
      expect(p.isItalic, isFalse);
      expect(p.fontSize, 16.0);
      expect(p.alignment, TextAlign.center);
      expect(p.headingStyle, 'heading1');

      final copy = p.copy();
      expect(copy.isBold, isTrue);
      expect(copy.headingStyle, 'heading1');
    });

    test(
        'A4DocumentModel calculates word count accurately across paragraphs and tables',
        () {
      final p1 = DocParagraphItem(id: '1', text: 'Hello world from Flutter');
      final table = DocTableItem(
        id: 'tbl_1',
        rows: [
          [DocTableCell(text: 'Item Alpha'), DocTableCell(text: 'Value 100')],
          [DocTableCell(text: 'Item Beta'), DocTableCell(text: 'Value 200')],
        ],
      );

      final doc = A4DocumentModel(
        originalPath: 'test.docx',
        title: 'test.docx',
        fileType: 'DOCX',
        items: [p1, table],
      );

      expect(doc.items.length, 2);
      expect(doc.wordCount, 12); // 4 words in p1 + 8 words in table
    });
  });

  group('Feature 5: PDF Editor Studio Tests', () {
    test('EditorElement models copy and preserve properties for undo/redo', () {
      final textElem = TextEditorElement(
        id: 'txt_1',
        pageIndex: 0,
        text: 'Approved & Verified',
        position: const Offset(100, 200),
        fontSize: 14.0,
        color: Colors.red,
        isBold: true,
      );

      final copiedText = textElem.copy();
      expect(copiedText.id, textElem.id);
      expect(copiedText.text, 'Approved & Verified');
      expect(copiedText.position, const Offset(100, 200));
      expect(copiedText.color, Colors.red);
      expect(copiedText.isBold, isTrue);

      final shapeElem = ShapeEditorElement(
        id: 'shape_1',
        pageIndex: 0,
        type: EditorToolType.rectangle,
        bounds: const Rect.fromLTWH(50, 50, 200, 100),
        strokeWidth: 4.0,
      );

      final copiedShape = shapeElem.copy();
      expect(copiedShape.bounds, const Rect.fromLTWH(50, 50, 200, 100));
      expect(copiedShape.strokeWidth, 4.0);

      final drawingElem = DrawingEditorElement(
        id: 'draw_1',
        pageIndex: 1,
        points: const [Offset(10, 10), Offset(20, 20), Offset(30, 25)],
      );

      final copiedDrawing = drawingElem.copy();
      expect(copiedDrawing.points.length, 3);
      expect(copiedDrawing.pageIndex, 1);

      final replaceElem = ReplaceTextEditorElement(
        id: 'rep_1',
        pageIndex: 0,
        originalBounds: const Rect.fromLTWH(10, 10, 80, 20),
        newText: 'Updated Clause',
      );
      final copiedReplace = replaceElem.copy();
      expect(copiedReplace.newText, 'Updated Clause');

      final annotationElem = AnnotationEditorElement(
        id: 'note_1',
        pageIndex: 0,
        position: const Offset(40, 60),
        noteText: 'Please review page 1 clause',
        color: const Color(0xFFFFEB3B),
        opacity: 0.9,
      );
      final copiedAnnotation = annotationElem.copy();
      expect(copiedAnnotation.noteText, 'Please review page 1 clause');
      expect(copiedAnnotation.position, const Offset(40, 60));
      expect(copiedAnnotation.opacity, 0.9);
      expect(copiedAnnotation.type, EditorToolType.annotation);
    });

    test('TextEditorElement supports mobile formatting properties', () {
      final advancedText = TextEditorElement(
        id: 'txt_adv',
        pageIndex: 0,
        text: 'Mobile First PDF Editor',
        position: const Offset(15, 25),
        fontSize: 18.0,
        fontFamily: 'Courier',
        isBold: true,
        isItalic: true,
        alignment: TextAlign.center,
        opacity: 0.85,
      );

      final copy = advancedText.copy();
      expect(copy.fontFamily, 'Courier');
      expect(copy.isItalic, isTrue);
      expect(copy.alignment, TextAlign.center);
      expect(copy.opacity, 0.85);
      expect(copy.isUnderline, isFalse);

      final underlinedText = advancedText.copy()..isUnderline = true;
      expect(underlinedText.isUnderline, isTrue);
    });
  });
}
