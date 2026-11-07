import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import '../models/pdf_file_model.dart';
import 'file_service.dart';

enum DocItemType {
  paragraph,
  heading,
  table,
  image,
  pageBreak,
}

abstract class DocItem {
  final String id;
  final DocItemType type;

  DocItem({required this.id, required this.type});

  DocItem copy();
}

class DocParagraphItem extends DocItem {
  String text;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  double fontSize;
  TextAlign alignment;
  String headingStyle; // 'normal', 'title', 'heading1', 'heading2'
  Color color;

  DocParagraphItem({
    required super.id,
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize = 13.0,
    this.alignment = TextAlign.left,
    this.headingStyle = 'normal',
    this.color = Colors.black,
  }) : super(
            type: headingStyle == 'normal'
                ? DocItemType.paragraph
                : DocItemType.heading);

  @override
  DocParagraphItem copy() => DocParagraphItem(
        id: id,
        text: text,
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        fontSize: fontSize,
        alignment: alignment,
        headingStyle: headingStyle,
        color: color,
      );
}

class DocTableCell {
  String text;
  bool isHeader;
  TextAlign alignment;

  DocTableCell({
    required this.text,
    this.isHeader = false,
    this.alignment = TextAlign.left,
  });

  DocTableCell copy() => DocTableCell(
        text: text,
        isHeader: isHeader,
        alignment: alignment,
      );
}

class DocTableItem extends DocItem {
  List<List<DocTableCell>> rows;

  DocTableItem({
    required super.id,
    required this.rows,
  }) : super(type: DocItemType.table);

  @override
  DocTableItem copy() => DocTableItem(
        id: id,
        rows: rows.map((r) => r.map((c) => c.copy()).toList()).toList(),
      );
}

class DocImageItem extends DocItem {
  Uint8List imageBytes;
  double width;
  double height;
  TextAlign alignment;

  DocImageItem({
    required super.id,
    required this.imageBytes,
    this.width = 320,
    this.height = 200,
    this.alignment = TextAlign.center,
  }) : super(type: DocItemType.image);

  @override
  DocImageItem copy() => DocImageItem(
        id: id,
        imageBytes: imageBytes,
        width: width,
        height: height,
        alignment: alignment,
      );
}

class DocPageBreakItem extends DocItem {
  DocPageBreakItem({required super.id}) : super(type: DocItemType.pageBreak);

  @override
  DocPageBreakItem copy() => DocPageBreakItem(id: id);
}

class A4DocumentModel {
  final String originalPath;
  final String title;
  final String fileType; // 'DOCX' or 'TXT'
  final List<DocItem> items;
  final Uint8List? rawArchiveBytes;

  A4DocumentModel({
    required this.originalPath,
    required this.title,
    required this.fileType,
    required this.items,
    this.rawArchiveBytes,
  });

  A4DocumentModel copy() => A4DocumentModel(
        originalPath: originalPath,
        title: title,
        fileType: fileType,
        items: items.map((e) => e.copy()).toList(),
        rawArchiveBytes: rawArchiveBytes,
      );

  int get wordCount {
    int total = 0;
    for (final it in items) {
      if (it is DocParagraphItem && it.text.trim().isNotEmpty) {
        total += it.text.trim().split(RegExp(r'\s+')).length;
      } else if (it is DocTableItem) {
        for (final row in it.rows) {
          for (final c in row) {
            if (c.text.trim().isNotEmpty) {
              total += c.text.trim().split(RegExp(r'\s+')).length;
            }
          }
        }
      }
    }
    return total;
  }
}

class DocumentEditorService {
  static final DocumentEditorService _instance =
      DocumentEditorService._internal();
  factory DocumentEditorService() => _instance;
  DocumentEditorService._internal();

  final FileService _fileService = FileService();

  /// Loads and parses DOCX preserving layout, headings, tables, and images
  Future<A4DocumentModel> loadDocument(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final ext = filePath.split('.').last.toLowerCase();
    final name = file.path.split(Platform.pathSeparator).last;

    if (ext == 'docx') {
      return await _loadDocx(file, name);
    } else {
      return await _loadTxt(file, name);
    }
  }

  Future<A4DocumentModel> _loadTxt(File file, String title) async {
    final content = await file.readAsString();
    final blocks = content.split(RegExp(r'\r?\n\r?\n'));
    final List<DocItem> items = [];

    int index = 0;
    for (final b in blocks) {
      final trimmed = b.trim();
      if (trimmed.isNotEmpty) {
        items.add(
          DocParagraphItem(
            id: 'item_${index++}',
            text: trimmed,
            fontSize: 13.0,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(DocParagraphItem(id: 'item_0', text: '', fontSize: 13.0));
    }

    return A4DocumentModel(
      originalPath: file.path,
      title: title,
      fileType: 'TXT',
      items: items,
    );
  }

  Future<A4DocumentModel> _loadDocx(File file, String title) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXmlFile = archive.findFile('word/document.xml');

    if (docXmlFile == null) {
      throw const FormatException(
          'Invalid DOCX format: word/document.xml missing');
    }

    // Load relationships to map image rId -> file path in media
    final Map<String, String> imageRels = {};
    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    if (relsFile != null) {
      try {
        final relsXml = utf8.decode(relsFile.content as List<int>);
        final relsDoc = XmlDocument.parse(relsXml);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null && target.contains('media/')) {
            imageRels[id] =
                target.startsWith('media/') ? 'word/$target' : target;
          }
        }
      } catch (_) {}
    }

    final xmlContent = utf8.decode(docXmlFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);

    final List<DocItem> items = [];
    int itemCounter = 0;

    final body = document.findAllElements('w:body').firstOrNull;
    if (body != null) {
      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          // Check for Page Break
          if (child
                  .findAllElements('w:br')
                  .any((b) => b.getAttribute('w:type') == 'page') ||
              child.findAllElements('w:lastRenderedPageBreak').isNotEmpty) {
            items.add(DocPageBreakItem(id: 'pb_${itemCounter++}'));
          }

          // Check for embedded images via drawing blip
          for (final blip in child.findAllElements('a:blip')) {
            final embedId = blip.getAttribute('r:embed');
            if (embedId != null && imageRels.containsKey(embedId)) {
              final mediaPath = imageRels[embedId]!;
              final mediaFile = archive.findFile(mediaPath);
              if (mediaFile != null) {
                items.add(
                  DocImageItem(
                    id: 'img_${itemCounter++}',
                    imageBytes: mediaFile.content,
                  ),
                );
              }
            }
          }

          // Extract Paragraph Text and Styles
          final StringBuffer textBuffer = StringBuffer();
          bool bold = false;
          bool italic = false;
          bool underline = false;
          double fontSize = 13.0;
          TextAlign alignment = TextAlign.left;
          String headingStyle = 'normal';

          // Alignment
          final jc = child.findAllElements('w:jc').firstOrNull;
          if (jc != null) {
            final val = jc.getAttribute('w:val');
            if (val == 'center') alignment = TextAlign.center;
            if (val == 'right') alignment = TextAlign.right;
            if (val == 'both') alignment = TextAlign.justify;
          }

          // Heading Style
          final pStyle = child.findAllElements('w:pStyle').firstOrNull;
          if (pStyle != null) {
            final val = pStyle.getAttribute('w:val')?.toLowerCase() ?? '';
            if (val.contains('title')) {
              headingStyle = 'title';
              fontSize = 22.0;
              bold = true;
            } else if (val.contains('heading1') || val == 'h1') {
              headingStyle = 'heading1';
              fontSize = 18.0;
              bold = true;
            } else if (val.contains('heading2') || val == 'h2') {
              headingStyle = 'heading2';
              fontSize = 15.0;
              bold = true;
            }
          }

          // Runs
          for (final rNode in child.findAllElements('w:r')) {
            final rPr = rNode.findElements('w:rPr').firstOrNull;
            if (rPr != null) {
              if (rPr.findElements('w:b').isNotEmpty) bold = true;
              if (rPr.findElements('w:i').isNotEmpty) italic = true;
              if (rPr.findElements('w:u').isNotEmpty) underline = true;
              final sz =
                  rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val');
              if (sz != null && double.tryParse(sz) != null) {
                fontSize = double.parse(sz) / 2.0;
              }
            }

            for (final t in rNode.findElements('w:t')) {
              textBuffer.write(t.innerText);
            }
          }

          final text = textBuffer.toString().trim();
          if (text.isNotEmpty) {
            items.add(
              DocParagraphItem(
                id: 'p_${itemCounter++}',
                text: text,
                isBold: bold,
                isItalic: italic,
                isUnderline: underline,
                fontSize: fontSize.clamp(8.0, 36.0),
                alignment: alignment,
                headingStyle: headingStyle,
              ),
            );
          }
        } else if (child.name.local == 'tbl') {
          // Table parsing
          final List<List<DocTableCell>> tableRows = [];
          for (final tr in child.findAllElements('w:tr')) {
            final List<DocTableCell> rowCells = [];
            for (final tc in tr.findAllElements('w:tc')) {
              final cellText = tc
                  .findAllElements('w:t')
                  .map((e) => e.innerText)
                  .join(' ')
                  .trim();
              final isHeader = tr.findAllElements('w:tblHeader').isNotEmpty;
              rowCells.add(DocTableCell(text: cellText, isHeader: isHeader));
            }
            if (rowCells.isNotEmpty) {
              tableRows.add(rowCells);
            }
          }
          if (tableRows.isNotEmpty) {
            items
                .add(DocTableItem(id: 'tbl_${itemCounter++}', rows: tableRows));
          }
        }
      }
    }

    if (items.isEmpty) {
      items.add(DocParagraphItem(id: 'p_0', text: '', fontSize: 13.0));
    }

    return A4DocumentModel(
      originalPath: file.path,
      title: title,
      fileType: 'DOCX',
      items: items,
      rawArchiveBytes: bytes,
    );
  }

  /// Exports document as standard multi-page PDF preserving A4 pages, headings, tables, and images
  Future<PdfFileModel> exportAsPdf({
    required List<DocItem> items,
    required String documentTitle,
  }) async {
    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.margins.all = 40;

    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final h1Font =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final h2Font =
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 11);

    PdfPage page = pdfDocument.pages.add();
    double cursorY = 20.0;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    for (final item in items) {
      if (item is DocPageBreakItem) {
        page = pdfDocument.pages.add();
        cursorY = 20.0;
        continue;
      }

      if (item is DocImageItem) {
        if (cursorY + 160 > pageHeight - 40) {
          page = pdfDocument.pages.add();
          cursorY = 20.0;
        }
        try {
          final bitmap = PdfBitmap(item.imageBytes);
          final drawWidth = (pageWidth * 0.7).clamp(150.0, 400.0);
          final drawHeight = drawWidth * (bitmap.height / bitmap.width);
          final drawX = (pageWidth - drawWidth) / 2;
          page.graphics.drawImage(
              bitmap, Rect.fromLTWH(drawX, cursorY, drawWidth, drawHeight));
          cursorY += drawHeight + 16.0;
        } catch (_) {}
        continue;
      }

      if (item is DocTableItem) {
        if (item.rows.isEmpty) continue;
        final colCount = item.rows.first.length;
        if (colCount == 0) continue;

        final pdfGrid = PdfGrid();
        pdfGrid.columns.add(count: colCount);

        for (final row in item.rows) {
          final gridRow = pdfGrid.rows.add();
          for (int c = 0; c < row.length; c++) {
            gridRow.cells[c].value = row[c].text;
          }
        }

        pdfGrid.style = PdfGridStyle(
          font: regularFont,
          cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
        );

        final result = pdfGrid.draw(
          page: page,
          bounds: Rect.fromLTWH(0, cursorY, pageWidth, pageHeight - cursorY),
        );

        if (result != null) {
          cursorY = result.bounds.bottom + 16.0;
          if (cursorY > pageHeight - 40) {
            page = pdfDocument.pages.add();
            cursorY = 20.0;
          }
        }
        continue;
      }

      if (item is DocParagraphItem) {
        if (item.text.trim().isEmpty) continue;

        PdfStandardFont font;
        if (item.headingStyle == 'title') {
          font = titleFont;
        } else if (item.headingStyle == 'heading1') {
          font = h1Font;
        } else if (item.headingStyle == 'heading2') {
          font = h2Font;
        } else {
          PdfFontStyle style = PdfFontStyle.regular;
          if (item.isBold && item.isItalic) {
            style = PdfFontStyle.bold;
          } else if (item.isBold) {
            style = PdfFontStyle.bold;
          } else if (item.isItalic) {
            style = PdfFontStyle.italic;
          } else if (item.isUnderline) {
            style = PdfFontStyle.underline;
          }
          font = PdfStandardFont(
              PdfFontFamily.helvetica, item.fontSize.clamp(8, 28),
              style: style);
        }

        final textFormat = PdfStringFormat();
        if (item.alignment == TextAlign.center) {
          textFormat.alignment = PdfTextAlignment.center;
        }
        if (item.alignment == TextAlign.right) {
          textFormat.alignment = PdfTextAlignment.right;
        }
        if (item.alignment == TextAlign.justify) {
          textFormat.alignment = PdfTextAlignment.justify;
        }

        final textElement = PdfTextElement(
          text: item.text,
          font: font,
          brush: PdfSolidBrush(PdfColor(
            (item.color.r * 255).round(),
            (item.color.g * 255).round(),
            (item.color.b * 255).round(),
          )),
          format: textFormat,
        );

        final layoutResult = textElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, cursorY, pageWidth, pageHeight - cursorY),
        );

        if (layoutResult != null) {
          cursorY = layoutResult.bounds.bottom +
              (item.headingStyle != 'normal' ? 16.0 : 10.0);
          if (cursorY > pageHeight - 40) {
            page = pdfDocument.pages.add();
            cursorY = 20.0;
          }
        }
      }
    }

    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    final pageCount = pdfDocument.pages.count;
    pdfDocument.dispose();

    final baseName =
        documentTitle.replaceAll('.docx', '').replaceAll('.txt', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outName = 'Edited_${baseName}_$timestamp.pdf';

    return await _fileService.savePdfBytes(
      outputBytes,
      outName,
      operationType: 'Edited Document',
      pageCount: pageCount,
    );
  }

  /// Saves updated document into a genuine .docx package
  Future<File> saveAsDocx({
    required List<DocItem> items,
    required String originalPath,
    Uint8List? rawArchiveBytes,
  }) async {
    final appDir = await _fileService.getAppPdfDirectory();
    final baseName = originalPath
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.docx', '')
        .replaceAll('.txt', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outPath =
        '${appDir.path}${Platform.pathSeparator}Edited_${baseName}_$timestamp.docx';

    Archive archive;
    if (rawArchiveBytes != null) {
      archive = ZipDecoder().decodeBytes(rawArchiveBytes);
    } else {
      archive = _createMinimalDocxArchive();
    }

    // Build new word/document.xml with full headings, tables, and paragraphs
    final xmlBuilder = XmlBuilder();
    xmlBuilder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    xmlBuilder.element('w:document', namespaces: {
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main': 'w',
    }, nest: () {
      xmlBuilder.element('w:body', nest: () {
        for (final it in items) {
          if (it is DocPageBreakItem) {
            xmlBuilder.element('w:p', nest: () {
              xmlBuilder.element('w:r', nest: () {
                xmlBuilder.element('w:br', attributes: {'w:type': 'page'});
              });
            });
          } else if (it is DocTableItem) {
            xmlBuilder.element('w:tbl', nest: () {
              for (final row in it.rows) {
                xmlBuilder.element('w:tr', nest: () {
                  for (final cell in row) {
                    xmlBuilder.element('w:tc', nest: () {
                      xmlBuilder.element('w:p', nest: () {
                        xmlBuilder.element('w:r', nest: () {
                          if (cell.isHeader) {
                            xmlBuilder.element('w:rPr', nest: () {
                              xmlBuilder.element('w:b');
                            });
                          }
                          xmlBuilder.element('w:t', nest: cell.text);
                        });
                      });
                    });
                  }
                });
              }
            });
          } else if (it is DocParagraphItem) {
            xmlBuilder.element('w:p', nest: () {
              // Paragraph Properties
              xmlBuilder.element('w:pPr', nest: () {
                if (it.headingStyle == 'title') {
                  xmlBuilder
                      .element('w:pStyle', attributes: {'w:val': 'Title'});
                } else if (it.headingStyle == 'heading1') {
                  xmlBuilder
                      .element('w:pStyle', attributes: {'w:val': 'Heading1'});
                } else if (it.headingStyle == 'heading2') {
                  xmlBuilder
                      .element('w:pStyle', attributes: {'w:val': 'Heading2'});
                }

                if (it.alignment == TextAlign.center) {
                  xmlBuilder.element('w:jc', attributes: {'w:val': 'center'});
                } else if (it.alignment == TextAlign.right) {
                  xmlBuilder.element('w:jc', attributes: {'w:val': 'right'});
                } else if (it.alignment == TextAlign.justify) {
                  xmlBuilder.element('w:jc', attributes: {'w:val': 'both'});
                }
              });

              // Run
              xmlBuilder.element('w:r', nest: () {
                xmlBuilder.element('w:rPr', nest: () {
                  if (it.isBold) xmlBuilder.element('w:b');
                  if (it.isItalic) xmlBuilder.element('w:i');
                  if (it.isUnderline) {
                    xmlBuilder.element('w:u', attributes: {'w:val': 'single'});
                  }
                  final halfPoints = (it.fontSize * 2).round().toString();
                  xmlBuilder.element('w:sz', attributes: {'w:val': halfPoints});
                });
                xmlBuilder.element('w:t', nest: it.text);
              });
            });
          }
        }
      });
    });

    final newXmlString = xmlBuilder.buildDocument().toXmlString(pretty: true);
    final newXmlBytes = utf8.encode(newXmlString);

    final newArchive = Archive();
    for (final f in archive) {
      if (f.name != 'word/document.xml') {
        newArchive.addFile(f);
      }
    }
    newArchive.addFile(
        ArchiveFile('word/document.xml', newXmlBytes.length, newXmlBytes));

    final zipData = ZipEncoder().encode(newArchive, level: 9);
    final outFile = File(outPath);
    await outFile.writeAsBytes(zipData);
    return outFile;
  }

  /// Saves updated paragraphs as a .txt file
  Future<File> saveAsTxt({
    required List<DocItem> items,
    required String originalPath,
  }) async {
    final appDir = await _fileService.getAppPdfDirectory();
    final baseName = originalPath
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.docx', '')
        .replaceAll('.txt', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outPath =
        '${appDir.path}${Platform.pathSeparator}Edited_${baseName}_$timestamp.txt';

    final buffer = StringBuffer();
    for (final it in items) {
      if (it is DocParagraphItem) {
        buffer.writeln(it.text);
        buffer.writeln();
      } else if (it is DocTableItem) {
        for (final row in it.rows) {
          buffer.writeln(row.map((c) => c.text).join('\t'));
        }
        buffer.writeln();
      }
    }

    final outFile = File(outPath);
    await outFile.writeAsString(buffer.toString());
    return outFile;
  }

  Archive _createMinimalDocxArchive() {
    final archive = Archive();
    const contentTypes =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    final ctBytes = utf8.encode(contentTypes);
    archive
        .addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    final relsBytes = utf8.encode(rootRels);
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));

    return archive;
  }
}
