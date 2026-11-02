import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';

class PdfConversionService {
  static final PdfConversionService _instance =
      PdfConversionService._internal();
  factory PdfConversionService() => _instance;
  PdfConversionService._internal();

  final FileService _fileService = FileService();

  /// Converts PDF document into a valid Microsoft Word (.docx) OpenXML file
  Future<File> pdfToWord({
    required String filePath,
    String? outputName,
  }) async {
    final pdfBytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);

    final paragraphs = <String>[];
    for (int i = 0; i < document.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      final lines = text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          paragraphs.add(trimmed);
        }
      }
      if (i < document.pages.count - 1) {
        paragraphs.add('--- Page Break ---');
      }
    }
    document.dispose();

    // Build standard OpenXML DOCX archive
    final docxArchive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    docxArchive.addFile(ArchiveFile('[Content_Types].xml',
        contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const rootRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    docxArchive.addFile(ArchiveFile(
        '_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. word/document.xml
    final docXmlBuffer = StringBuffer();
    docXmlBuffer
        .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docXmlBuffer.writeln(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docXmlBuffer.writeln('<w:body>');

    for (final p in paragraphs) {
      final safeText = _escapeXml(p);
      if (p == '--- Page Break ---') {
        docXmlBuffer.writeln('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      } else {
        docXmlBuffer.writeln('<w:p><w:r><w:t>$safeText</w:t></w:r></w:p>');
      }
    }

    docXmlBuffer.writeln(
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>');
    docXmlBuffer.writeln('</w:body></w:document>');

    final docXmlBytes = utf8.encode(docXmlBuffer.toString());
    docxArchive.addFile(
        ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));

    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final docxBytes = zipEncoder.encode(docxArchive);

    final baseDir = await _fileService.getAppPdfDirectory();
    final name = outputName?.trim().isNotEmpty == true
        ? (outputName!.endsWith('.docx') ? outputName : '$outputName.docx')
        : FileUtils.generateOutputFileName('Converted', 'docx');

    final targetPath = '${baseDir.path}${Platform.pathSeparator}$name';
    final resultFile = File(targetPath);
    await resultFile.writeAsBytes(docxBytes, flush: true);
    return resultFile;
  }

  /// Converts PDF tabular content into a valid Microsoft Excel (.xlsx) OpenXML workbook
  Future<File> pdfToExcel({
    required String filePath,
    String? outputName,
  }) async {
    final pdfBytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);

    final rows = <List<String>>[];
    for (int i = 0; i < document.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      final lines = text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Split by tabs, commas, or multiple spaces to detect columns
        List<String> cells;
        if (trimmed.contains('\t')) {
          cells = trimmed.split('\t');
        } else if (trimmed.contains(',') && !trimmed.startsWith('"')) {
          cells = trimmed.split(',');
        } else {
          cells = trimmed.split(RegExp(r'\s{2,}'));
        }
        rows.add(
            cells.map((c) => c.trim()).where((c) => c.isNotEmpty).toList());
      }
    }
    document.dispose();

    if (rows.isEmpty) {
      rows.add(['No structured text found in PDF']);
    }

    // Build standard OpenXML XLSX archive
    final xlsxArchive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
    xlsxArchive.addFile(ArchiveFile('[Content_Types].xml',
        contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const rootRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    xlsxArchive.addFile(ArchiveFile(
        '_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. xl/_rels/workbook.xml.rels
    const wbRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
    xlsxArchive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels',
        wbRelsXml.length, utf8.encode(wbRelsXml)));

    // 4. xl/workbook.xml
    const workbookXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>''';
    xlsxArchive.addFile(ArchiveFile(
        'xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)));

    // 5. xl/worksheets/sheet1.xml
    final sheetBuffer = StringBuffer();
    sheetBuffer
        .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheetBuffer.writeln(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheetBuffer.writeln('<sheetData>');

    for (int r = 0; r < rows.length; r++) {
      final rowNum = r + 1;
      final rowCells = rows[r];
      sheetBuffer.writeln('<row r="$rowNum">');
      for (int c = 0; c < rowCells.length; c++) {
        final colLetter = _getExcelColumnName(c);
        final cellRef = '$colLetter$rowNum';
        final val = _escapeXml(rowCells[c]);
        sheetBuffer
            .writeln('<c r="$cellRef" t="inlineStr"><is><t>$val</t></is></c>');
      }
      sheetBuffer.writeln('</row>');
    }

    sheetBuffer.writeln('</sheetData></worksheet>');
    final sheetBytes = utf8.encode(sheetBuffer.toString());
    xlsxArchive.addFile(
        ArchiveFile('xl/worksheets/sheet1.xml', sheetBytes.length, sheetBytes));

    final zipEncoder = ZipEncoder();
    final xlsxBytes = zipEncoder.encode(xlsxArchive);

    final baseDir = await _fileService.getAppPdfDirectory();
    final name = outputName?.trim().isNotEmpty == true
        ? (outputName!.endsWith('.xlsx') ? outputName : '$outputName.xlsx')
        : FileUtils.generateOutputFileName('Data_Sheet', 'xlsx');

    final targetPath = '${baseDir.path}${Platform.pathSeparator}$name';
    final resultFile = File(targetPath);
    await resultFile.writeAsBytes(xlsxBytes, flush: true);
    return resultFile;
  }

  /// Converts PDF pages into Microsoft PowerPoint presentation slides (.pptx)
  Future<File> pdfToPowerPoint({
    required String filePath,
    String? outputName,
  }) async {
    final pdfBytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);

    final slidesText = <List<String>>[];
    for (int i = 0; i < document.pages.count; i++) {
      final pageText =
          extractor.extractText(startPageIndex: i, endPageIndex: i);
      final lines = pageText
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      slidesText.add(lines.isNotEmpty ? lines : ['Slide ${i + 1} Content']);
    }
    document.dispose();

    final pptxArchive = Archive();

    // 1. [Content_Types].xml
    final ctBuffer = StringBuffer();
    ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ctBuffer.writeln(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    ctBuffer.writeln(
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    ctBuffer
        .writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    ctBuffer.writeln(
        '  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    for (int i = 1; i <= slidesText.length; i++) {
      ctBuffer.writeln(
          '  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    ctBuffer.writeln('</Types>');
    final ctBytes = utf8.encode(ctBuffer.toString());
    pptxArchive
        .addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    // 2. _rels/.rels
    const rootRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    pptxArchive.addFile(ArchiveFile(
        '_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. ppt/_rels/presentation.xml.rels
    final pRelsBuffer = StringBuffer();
    pRelsBuffer
        .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    pRelsBuffer.writeln(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (int i = 1; i <= slidesText.length; i++) {
      pRelsBuffer.writeln(
          '  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    pRelsBuffer.writeln('</Relationships>');
    final pRelsBytes = utf8.encode(pRelsBuffer.toString());
    pptxArchive.addFile(ArchiveFile(
        'ppt/_rels/presentation.xml.rels', pRelsBytes.length, pRelsBytes));

    // 4. ppt/presentation.xml
    final presBuffer = StringBuffer();
    presBuffer
        .writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presBuffer.writeln(
        '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    presBuffer.writeln('  <p:sldIdLst>');
    for (int i = 1; i <= slidesText.length; i++) {
      final sldId = 255 + i;
      presBuffer.writeln('    <p:sldId id="$sldId" r:id="rId$i"/>');
    }
    presBuffer.writeln('  </p:sldIdLst>');
    presBuffer.writeln('  <p:sldSz cx="9144000" cy="6858000"/>');
    presBuffer.writeln('</p:presentation>');
    final presBytes = utf8.encode(presBuffer.toString());
    pptxArchive.addFile(
        ArchiveFile('ppt/presentation.xml', presBytes.length, presBytes));

    // 5. Individual slides
    for (int i = 1; i <= slidesText.length; i++) {
      final lines = slidesText[i - 1];
      final title = _escapeXml(lines.isNotEmpty ? lines.first : 'Slide $i');
      final body = lines.length > 1
          ? lines
              .skip(1)
              .take(8)
              .map((l) => '<a:p><a:r><a:t>${_escapeXml(l)}</a:t></a:r></a:p>')
              .join()
          : '<a:p><a:r><a:t>Page $i Content</a:t></a:r></a:p>';

      final slideXml =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="685800" y="609600"/><a:ext cx="7772400" cy="914400"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:p><a:r><a:t>$title</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="685800" y="1676400"/><a:ext cx="7772400" cy="4572000"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/>$body</p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      final sBytes = utf8.encode(slideXml);
      pptxArchive.addFile(
          ArchiveFile('ppt/slides/slide$i.xml', sBytes.length, sBytes));
    }

    final zipEncoder = ZipEncoder();
    final pptxBytes = zipEncoder.encode(pptxArchive);

    final baseDir = await _fileService.getAppPdfDirectory();
    final name = outputName?.trim().isNotEmpty == true
        ? (outputName!.endsWith('.pptx') ? outputName : '$outputName.pptx')
        : FileUtils.generateOutputFileName('Presentation', 'pptx');

    final targetPath = '${baseDir.path}${Platform.pathSeparator}$name';
    final resultFile = File(targetPath);
    await resultFile.writeAsBytes(pptxBytes, flush: true);
    return resultFile;
  }

  /// Converts Microsoft Word (.docx) file into a formatted PDF
  Future<PdfFileModel> wordToPdf({
    required String filePath,
    String? outputName,
  }) async {
    final docxFile = File(filePath);
    final bytes = await docxFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find word/document.xml
    final docFile = archive.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () =>
          throw Exception('Invalid DOCX format: missing word/document.xml'),
    );

    final xmlContent = utf8.decode(docFile.content as List<int>);
    final parsed = xml.XmlDocument.parse(xmlContent);

    // Extract all paragraphs
    final paragraphs = <String>[];
    for (final pNode in parsed.findAllElements('w:p')) {
      final tNodes = pNode.findAllElements('w:t');
      final text = tNodes.map((n) => n.innerText).join();
      if (text.trim().isNotEmpty) {
        paragraphs.add(text.trim());
      }
    }

    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.margins.all = 36;
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final headingFont =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);

    var page = pdfDocument.pages.add();
    var yOffset = 0.0;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      final isHeading = i == 0 || p.length < 50 && p.endsWith(':');
      final currentFont = isHeading ? headingFont : font;

      // Wrap text within page bounds
      final layoutResult = PdfTextElement(
        text: p,
        font: currentFont,
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, yOffset, page.graphics.clientSize.width, 0),
      );

      if (layoutResult != null) {
        yOffset = layoutResult.bounds.bottom + (isHeading ? 14 : 8);
        if (yOffset > page.graphics.clientSize.height - 40) {
          page = pdfDocument.pages.add();
          yOffset = 0;
        }
      }
    }

    final pageCount = pdfDocument.pages.count;
    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    pdfDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Word_Converted');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'WordToPdf',
      pageCount: pageCount,
    );
  }

  /// Converts Microsoft Excel (.xlsx) spreadsheet into a formatted PDF grid table
  Future<PdfFileModel> excelToPdf({
    required String filePath,
    String? outputName,
  }) async {
    final xlsxFile = File(filePath);
    final bytes = await xlsxFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract shared strings if present
    final sharedStrings = <String>[];
    try {
      final sFile = archive.firstWhere((f) => f.name == 'xl/sharedStrings.xml');
      final sXml =
          xml.XmlDocument.parse(utf8.decode(sFile.content as List<int>));
      for (final t in sXml.findAllElements('t')) {
        sharedStrings.add(t.innerText);
      }
    } catch (_) {}

    // Extract sheet1.xml
    final sheetFile = archive.firstWhere(
      (f) => f.name == 'xl/worksheets/sheet1.xml',
      orElse: () => throw Exception('Invalid XLSX format: missing sheet1.xml'),
    );

    final sheetXml =
        xml.XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
    final rowNodes = sheetXml.findAllElements('row').toList();

    final tableData = <List<String>>[];
    for (final row in rowNodes) {
      final cellNodes = row.findAllElements('c');
      final cells = <String>[];
      for (final cell in cellNodes) {
        final type = cell.getAttribute('t');
        final vNode = cell.findElements('v').firstOrNull;
        final isNode =
            cell.findElements('is').firstOrNull?.findElements('t').firstOrNull;

        if (isNode != null) {
          cells.add(isNode.innerText);
        } else if (vNode != null) {
          final val = vNode.innerText;
          if (type == 's' && sharedStrings.isNotEmpty) {
            final sIdx = int.tryParse(val);
            if (sIdx != null && sIdx < sharedStrings.length) {
              cells.add(sharedStrings[sIdx]);
            } else {
              cells.add(val);
            }
          } else {
            cells.add(val);
          }
        }
      }
      if (cells.isNotEmpty) {
        tableData.add(cells);
      }
    }

    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.orientation = PdfPageOrientation.landscape;
    pdfDocument.pageSettings.margins.all = 30;

    final page = pdfDocument.pages.add();

    // Create table grid
    final grid = PdfGrid();
    if (tableData.isNotEmpty) {
      final maxCols =
          tableData.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      grid.columns.add(count: maxCols.clamp(1, 10));

      for (int r = 0; r < tableData.length; r++) {
        final row = grid.rows.add();
        final cells = tableData[r];
        for (int c = 0; c < cells.length && c < grid.columns.count; c++) {
          row.cells[c].value = cells[c];
        }
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
        font: PdfStandardFont(PdfFontFamily.helvetica, 10),
      );
      grid.draw(
          page: page,
          bounds: Rect.fromLTWH(0, 0, page.graphics.clientSize.width, 0));
    }

    final pageCount = pdfDocument.pages.count;
    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    pdfDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Excel_Converted');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'ExcelToPdf',
      pageCount: pageCount,
    );
  }

  /// Converts PowerPoint (.pptx) presentation slides into a landscape PDF handout
  Future<PdfFileModel> powerPointToPdf({
    required String filePath,
    String? outputName,
  }) async {
    final pptxFile = File(filePath);
    final bytes = await pptxFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find all slide XML files
    final slideFiles = archive
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList();

    slideFiles.sort((a, b) {
      final numA =
          int.tryParse(RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ?? 0;
      final numB =
          int.tryParse(RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.orientation = PdfPageOrientation.landscape;
    pdfDocument.pageSettings.margins.all = 36;

    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 13);

    for (final sFile in slideFiles) {
      final sXml =
          xml.XmlDocument.parse(utf8.decode(sFile.content as List<int>));
      final textNodes = sXml
          .findAllElements('a:t')
          .map((n) => n.innerText.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final page = pdfDocument.pages.add();
      final title = textNodes.isNotEmpty ? textNodes.first : 'Slide';
      final bodyLines = textNodes.skip(1).toList();

      page.graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(0, 20, page.graphics.clientSize.width, 30),
      );

      var y = 70.0;
      for (final line in bodyLines) {
        page.graphics.drawString(
          '• $line',
          bodyFont,
          bounds: Rect.fromLTWH(20, y, page.graphics.clientSize.width - 40, 24),
        );
        y += 24.0;
        if (y > page.graphics.clientSize.height - 40) break;
      }
    }

    if (pdfDocument.pages.count == 0) {
      pdfDocument.pages.add();
    }

    final pageCount = pdfDocument.pages.count;
    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    pdfDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Presentation_Converted');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'PptToPdf',
      pageCount: pageCount,
    );
  }

  /// Converts HTML string or fetched Webpage into a structured PDF without WebView
  Future<PdfFileModel> htmlToPdf({
    String? htmlContent,
    String? url,
    String? outputName,
  }) async {
    String rawHtml = htmlContent ?? '';
    if (url != null && url.trim().isNotEmpty) {
      final uri = Uri.parse(
          url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        rawHtml = response.body;
      } else {
        throw Exception('Failed to load webpage: HTTP ${response.statusCode}');
      }
    }

    if (rawHtml.trim().isEmpty) {
      throw ArgumentError('No HTML content provided.');
    }

    // Clean scripts & styles
    final cleaned = rawHtml
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
            '');

    // Extract text blocks by tags
    final blocks = <Map<String, String>>[];
    final tagRegex = RegExp(
        r'<(h[1-6]|p|li|blockquote|td|th)[^>]*>([\s\S]*?)<\/\1>',
        caseSensitive: false);

    for (final match in tagRegex.allMatches(cleaned)) {
      final tag = match.group(1)!.toLowerCase();
      final inner = match
          .group(2)!
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .trim();
      if (inner.isNotEmpty) {
        blocks.add({'tag': tag, 'text': inner});
      }
    }

    if (blocks.isEmpty) {
      // Fallback: strip all tags
      final plain = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
      blocks.add({'tag': 'p', 'text': plain});
    }

    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.margins.all = 36;
    var page = pdfDocument.pages.add();
    var yOffset = 0.0;

    final h1Font =
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final h2Font =
        PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);

    for (final block in blocks) {
      final tag = block['tag']!;
      final text = block['text']!;
      PdfFont font = bodyFont;
      double spacing = 8.0;

      if (tag == 'h1') {
        font = h1Font;
        spacing = 14.0;
      } else if (tag == 'h2' || tag == 'h3') {
        font = h2Font;
        spacing = 10.0;
      }

      final layout = PdfTextElement(text: text, font: font).draw(
        page: page,
        bounds: Rect.fromLTWH(0, yOffset, page.graphics.clientSize.width, 0),
      );

      if (layout != null) {
        yOffset = layout.bounds.bottom + spacing;
        if (yOffset > page.graphics.clientSize.height - 40) {
          page = pdfDocument.pages.add();
          yOffset = 0;
        }
      }
    }

    final pageCount = pdfDocument.pages.count;
    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    pdfDocument.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('HTML_Converted');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'HtmlToPdf',
      pageCount: pageCount,
    );
  }

  /// Converts standard PDF into archival ISO-compliant PDF/A-1b format
  Future<PdfFileModel> pdfToPdfA({
    required String filePath,
    String? outputName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Load and re-save document with PDF/A-1b conformance level
    final document = PdfDocument(
      inputBytes: bytes,
      conformanceLevel: PdfConformanceLevel.a1b,
    );

    document.documentInformation.title =
        filePath.split(Platform.pathSeparator).last;
    document.documentInformation.author = 'VertexDocs Archival Engine';
    document.documentInformation.creator = 'VertexDocs PDF Suite';
    document.documentInformation.creationDate = DateTime.now();

    final outputBytes = Uint8List.fromList(document.saveSync());
    final pageCount = document.pages.count;
    document.dispose();

    final fileName = outputName?.trim().isNotEmpty == true
        ? outputName!.trim()
        : FileUtils.generateOutputFileName('Archival_PDFA');

    return await _fileService.savePdfBytes(
      outputBytes,
      fileName,
      operationType: 'PDF/A',
      pageCount: pageCount,
    );
  }

  /// Converts PDF pages into JPG images with customizable compression quality (1-100)
  Future<List<String>> pdfToJpg({
    required String filePath,
    int quality = 85,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(filePath);
    final outputDir = await _fileService.getAppPdfDirectory();
    final baseName =
        filePath.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

    final resultPaths = <String>[];

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (rendered != null && rendered.bytes.isNotEmpty) {
        // Decode PNG and encode as JPG with user quality
        final decoded = img.decodeImage(rendered.bytes);
        if (decoded != null) {
          final jpgBytes = img.encodeJpg(decoded, quality: quality);
          final jpgPath =
              '${outputDir.path}${Platform.pathSeparator}${baseName}_page_$i.jpg';
          final file = File(jpgPath);
          await file.writeAsBytes(jpgBytes);
          resultPaths.add(jpgPath);
        }
      }
    }

    await doc.close();
    return resultPaths;
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _getExcelColumnName(int colIndex) {
    String colName = '';
    int dividend = colIndex + 1;
    while (dividend > 0) {
      final modulo = (dividend - 1) % 26;
      colName = String.fromCharCode(65 + modulo) + colName;
      dividend = (dividend - modulo) ~/ 26;
    }
    return colName;
  }
}
