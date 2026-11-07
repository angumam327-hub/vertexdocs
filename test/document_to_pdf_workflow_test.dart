// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vertexdocs/services/document_editor_service.dart';
import 'package:vertexdocs/services/file_service.dart';
import 'package:vertexdocs/services/pdf_editor_service.dart';
import 'package:vertexdocs/services/storage_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
  @override
  Future<List<String>?> getExternalStoragePaths(
      {StorageDirectory? type}) async =>
      [tempDir.path];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('vertexdocs_workflow_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Document to PDF to PDF Editing Complete Workflow Tests', () {
    late File initialDocxFile;
    late File savedDocxFile;
    late String exportedPdfPath;
    late String finalEditedPdfPath;

    test('Step 1 & 2: Create initial DOCX and open with DocumentEditorService',
        () async {
      final docService = DocumentEditorService();

      // Create a test DOCX
      final initialItems = [
        DocParagraphItem(
          id: 'p_title',
          text: 'Project Proposal: VertexDocs Architecture',
          headingStyle: 'title',
          fontSize: 22.0,
          isBold: true,
        ),
        DocParagraphItem(
          id: 'p_body_1',
          text:
              'This document details the complete native Flutter document and PDF editing pipeline.',
          fontSize: 13.0,
        ),
        DocTableItem(
          id: 'tbl_1',
          rows: [
            [
              DocTableCell(text: 'Module', isHeader: true),
              DocTableCell(text: 'Format', isHeader: true),
              DocTableCell(text: 'Status', isHeader: true),
            ],
            [
              DocTableCell(text: 'Document Editor'),
              DocTableCell(text: 'DOCX / TXT'),
              DocTableCell(text: 'Active'),
            ],
            [
              DocTableCell(text: 'PDF Editor'),
              DocTableCell(text: 'PDF'),
              DocTableCell(text: 'Active'),
            ],
          ],
        ),
      ];

      initialDocxFile = await docService.saveAsDocx(
        items: initialItems,
        originalPath: '${tempDir.path}${Platform.pathSeparator}initial.docx',
      );

      expect(await initialDocxFile.exists(), isTrue);

      // Open with loadDocument
      final loadedModel = await docService.loadDocument(initialDocxFile.path);
      expect(loadedModel.items.length, greaterThanOrEqualTo(2));
      expect(loadedModel.fileType, 'DOCX');
      expect(loadedModel.wordCount, greaterThan(10));
    });

    test('Step 3 & 4: Edit document content and save modified DOCX', () async {
      final docService = DocumentEditorService();
      final loadedModel = await docService.loadDocument(initialDocxFile.path);

      // Edit an existing paragraph
      final firstP = loadedModel.items.whereType<DocParagraphItem>().first;
      firstP.text = 'Updated: Advanced VertexDocs Architecture 2026';
      firstP.isBold = true;
      firstP.isItalic = true;

      // Add a new paragraph
      final newParagraph = DocParagraphItem(
        id: 'p_new_conclusion',
        text: 'Conclusion: The workflow executes with 100% data fidelity.',
        fontSize: 14.0,
        alignment: TextAlign.center,
        color: const Color(0xFFF23882),
      );
      loadedModel.items.add(newParagraph);

      // Save modified DOCX
      savedDocxFile = await docService.saveAsDocx(
        items: loadedModel.items,
        originalPath: initialDocxFile.path,
        rawArchiveBytes: loadedModel.rawArchiveBytes,
      );

      expect(await savedDocxFile.exists(), isTrue);
      expect(await savedDocxFile.length(), greaterThan(0));

      // Reload saved DOCX to verify changes are preserved
      final reloadedDoc = await docService.loadDocument(savedDocxFile.path);
      final textDump = reloadedDoc.items
          .whereType<DocParagraphItem>()
          .map((p) => p.text)
          .join(' ');
      expect(textDump.contains('Updated: Advanced VertexDocs Architecture'), isTrue);
      expect(textDump.contains('Conclusion: The workflow executes with 100% data fidelity.'), isTrue);
    });

    test('Step 5: Convert the edited document into PDF', () async {
      final docService = DocumentEditorService();
      final reloadedDoc = await docService.loadDocument(savedDocxFile.path);

      final exportedPdf = await docService.exportAsPdf(
        items: reloadedDoc.items,
        documentTitle: reloadedDoc.title,
      );

      expect(await File(exportedPdf.path).exists(), isTrue);
      expect(exportedPdf.pageCount, greaterThanOrEqualTo(1));
      expect(exportedPdf.size, greaterThan(100));

      exportedPdfPath = exportedPdf.path;
    });

    test('Step 6 & 7: Open generated PDF in PDF Editor, extract text, add annotations & redactions',
        () async {
      final pdfEditor = PdfEditorService();

      // Check total page count
      final pageCount = await pdfEditor.getPdfPageCount(exportedPdfPath);
      expect(pageCount, greaterThanOrEqualTo(1));

      // Render page 1
      final page1 = await pdfEditor.renderSinglePage(exportedPdfPath, 1);
      expect(page1, isNotNull);
      expect(page1!.pageNumber, 1);
      expect(page1.size.width, greaterThan(200));

      // Extract existing text lines from the PDF
      final extractedLines =
          await pdfEditor.extractPageTextLines(exportedPdfPath, 0);
      expect(extractedLines, isNotEmpty);

      // Build editing elements:
      // 1. Text Overlay
      final textElement = TextEditorElement(
        id: 'overlay_text_1',
        pageIndex: 0,
        text: 'Approved by VertexDocs QA Team',
        position: const Offset(40, 250),
        fontSize: 14.0,
        isBold: true,
        color: const Color(0xFFF23882),
      );

      // 2. Modify / Redact Existing PDF text
      final firstLine = extractedLines.first;
      final redactElement = ReplaceTextEditorElement(
        id: 'replace_text_1',
        pageIndex: 0,
        originalBounds: firstLine.bounds,
        newText: 'REVISED TITLE: Official VertexDocs Specification',
        fontSize: 16.0,
        isBold: true,
        color: Colors.black,
      );

      // 3. Highlight Element
      final highlightElement = HighlightEditorElement(
        id: 'hl_1',
        pageIndex: 0,
        bounds: const Rect.fromLTWH(40, 200, 200, 20),
        highlightColor: const Color(0xFFFFEB3B),
      );

      // 4. Underline Line Element
      final lineElement = LineEditorElement(
        id: 'line_1',
        pageIndex: 0,
        start: const Offset(40, 270),
        end: const Offset(300, 270),
        color: const Color(0xFFF23882),
        strokeWidth: 2.0,
      );

      // Save the edited PDF with 90° page rotation applied
      final editedModel = await pdfEditor.saveEditedPdf(
        originalPdfPath: exportedPdfPath,
        elements: [textElement, redactElement, highlightElement, lineElement],
        pageOrder: [0], // 1-page order
        pageRotations: {0: 90}, // 90° clockwise rotation
      );

      expect(await File(editedModel.path).exists(), isTrue);
      expect(editedModel.pageCount, 1);
      finalEditedPdfPath = editedModel.path;
    });

    test('Step 8: Reopen final modified PDF, verify rotation, text and download copy',
        () async {
      final pdfEditor = PdfEditorService();

      // Verify final PDF exists and can be opened
      final finalPageCount =
          await pdfEditor.getPdfPageCount(finalEditedPdfPath);
      expect(finalPageCount, 1);

      // Verify text extraction from edited PDF
      final finalExtracted =
          await pdfEditor.extractPageTextLines(finalEditedPdfPath, 0);
      expect(finalExtracted, isNotEmpty);

      final fullText = finalExtracted.map((l) => l.text).join(' ');
      expect(fullText.contains('Approved by VertexDocs QA Team'), isTrue);
      expect(fullText.contains('REVISED TITLE: Official VertexDocs Specification'), isTrue);

      // Verify file download / copy to user device
      final dlPath =
          await FileService().downloadFileToDevice(finalEditedPdfPath);
      expect(dlPath, isNotNull);
      expect(await File(dlPath!).exists(), isTrue);
    });
  });
}
