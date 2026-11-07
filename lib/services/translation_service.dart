import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;
import '../models/pdf_file_model.dart';
import '../utils/file_utils.dart';
import 'file_service.dart';
import 'storage_service.dart';

class SupportedLanguage {
  final String code;
  final String name;
  final String nativeName;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  String get displayName => '$name ($nativeName)';
}

class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceFileName;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceFileName,
  });
}

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final FileService _fileService = FileService();
  final StorageService _storage = StorageService();

  static const List<SupportedLanguage> supportedLanguages = [
    SupportedLanguage(
        code: 'auto', name: 'Auto Detect', nativeName: 'Automatic'),
    SupportedLanguage(code: 'en', name: 'English', nativeName: 'English'),
    SupportedLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    SupportedLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    SupportedLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    SupportedLanguage(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
    SupportedLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    SupportedLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    SupportedLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
    SupportedLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
    SupportedLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    SupportedLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
    SupportedLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    SupportedLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    SupportedLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    SupportedLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    SupportedLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    SupportedLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    SupportedLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    SupportedLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    SupportedLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    SupportedLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
    SupportedLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    SupportedLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa'),
    SupportedLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    SupportedLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    SupportedLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    SupportedLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
    SupportedLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    SupportedLanguage(code: 'he', name: 'Hebrew', nativeName: 'עברית'),
    SupportedLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    SupportedLanguage(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
    SupportedLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română'),
    SupportedLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    SupportedLanguage(code: 'fa', name: 'Persian', nativeName: 'فارسی'),
    SupportedLanguage(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
  ];

  /// Extracts text from PDF, DOCX, or TXT
  Future<String> extractDocumentText(String filePath) async {
    final lower = filePath.toLowerCase();
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist at $filePath');
    }

    if (lower.endsWith('.pdf')) {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.trim();
    } else if (lower.endsWith('.docx')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () =>
            throw Exception('Invalid DOCX format: missing word/document.xml'),
      );
      final xmlContent = utf8.decode(docFile.content as List<int>);
      final parsed = xml.XmlDocument.parse(xmlContent);

      final paragraphs = <String>[];
      for (final pNode in parsed.findAllElements('w:p')) {
        final tNodes = pNode.findAllElements('w:t');
        final text = tNodes.map((n) => n.innerText).join();
        if (text.trim().isNotEmpty) {
          paragraphs.add(text.trim());
        }
      }
      return paragraphs.join('\n\n').trim();
    } else {
      // Treat as plain text
      return await file.readAsString();
    }
  }

  /// Translates document text with live chunk progress
  Future<TranslationResult> translateDocument({
    required String filePath,
    required String sourceCode,
    required String targetCode,
    Function(double progress, String status)? onProgress,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    onProgress?.call(0.1, 'Extracting document text...');

    final originalText = await extractDocumentText(filePath);
    if (originalText.isEmpty) {
      throw Exception('No readable text found in $fileName');
    }

    onProgress?.call(0.25, 'Analyzing text structure...');

    // Chunk text by paragraphs/sentences (approx 1200 chars each)
    final chunks = _splitIntoChunks(originalText, 1200);
    final translatedChunks = <String>[];

    final apiKey = _storage.getGeminiApiKey();

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final currentProgress = 0.25 + ((i + 1) / chunks.length) * 0.65;
      onProgress?.call(
          currentProgress, 'Translating part ${i + 1} of ${chunks.length}...');

      String translated;
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        try {
          translated = await _translateWithGemini(
            chunk: chunk,
            sourceCode: sourceCode,
            targetCode: targetCode,
            apiKey: apiKey,
          );
        } catch (_) {
          translated =
              await _translateWithFreeEngine(chunk, sourceCode, targetCode);
        }
      } else {
        translated =
            await _translateWithFreeEngine(chunk, sourceCode, targetCode);
      }
      translatedChunks.add(translated);
    }

    onProgress?.call(1.0, 'Translation complete!');
    final fullTranslated = translatedChunks.join('\n\n');

    return TranslationResult(
      originalText: originalText,
      translatedText: fullTranslated,
      sourceLanguage: sourceCode,
      targetLanguage: targetCode,
      sourceFileName: fileName,
    );
  }

  /// Free neural translation engine endpoint
  Future<String> _translateWithFreeEngine(
      String text, String sourceCode, String targetCode) async {
    final sl = sourceCode == 'auto' ? 'auto' : sourceCode;
    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$targetCode&dt=t&q=${Uri.encodeComponent(text)}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final buffer = StringBuffer();
          for (final item in data[0] as List) {
            if (item is List && item.isNotEmpty && item[0] is String) {
              buffer.write(item[0]);
            }
          }
          final res = buffer.toString().trim();
          if (res.isNotEmpty) return res;
        }
      }
    } catch (e) {
      debugPrint('Free translate engine error: $e');
    }

    // Secondary fallback: MyMemory Translation API
    try {
      final mmLang =
          '${sourceCode == "auto" ? "autodetect" : sourceCode}|$targetCode';
      final mmUri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$mmLang',
      );
      final mmRes = await http.get(mmUri).timeout(const Duration(seconds: 12));
      if (mmRes.statusCode == 200) {
        final data = jsonDecode(mmRes.body);
        final translated = data['responseData']?['translatedText'];
        if (translated != null &&
            translated is String &&
            translated.isNotEmpty) {
          return translated.trim();
        }
      }
    } catch (_) {}

    return text; // Return text safely if offline
  }

  /// Translation via Google Gemini API
  Future<String> _translateWithGemini({
    required String chunk,
    required String sourceCode,
    required String targetCode,
    required String apiKey,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final prompt =
        'Translate the following document excerpt accurately from $sourceCode to $targetCode. Maintain paragraph breaks and tone. Output only the translated text without commentary:\n\n$chunk';

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null && text is String) {
        return text.trim();
      }
    }
    throw Exception('Gemini translation error ${response.statusCode}');
  }

  /// Exports translated content into a clean, formatted multi-page PDF document
  Future<PdfFileModel> exportTranslatedPdf({
    required String translatedText,
    required String originalFileName,
    required String targetLanguage,
    String? outputName,
  }) async {
    final pdfDocument = PdfDocument();
    pdfDocument.pageSettings.margins.all = 40;

    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final headerFont =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final metaFont =
        PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);

    var page = pdfDocument.pages.add();

    // Header title
    final headerElement = PdfTextElement(
      text: 'Translated Document ($targetLanguage)',
      font: headerFont,
      brush: PdfSolidBrush(PdfColor(242, 56, 130)), // AppColors.primary
    );
    final headerLayout = headerElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
    );

    // Meta details
    final metaElement = PdfTextElement(
      text: 'Source: $originalFileName • Generated by VertexDocs Translator',
      font: metaFont,
      brush: PdfSolidBrush(PdfColor(107, 108, 126)),
    );
    final metaLayout = metaElement.draw(
      page: page,
      bounds: Rect.fromLTWH(
          0, headerLayout!.bounds.bottom + 4, page.getClientSize().width, 20),
    );

    // Divider line
    page.graphics.drawLine(
      PdfPen(PdfColor(243, 228, 235), width: 1),
      Offset(0, metaLayout!.bounds.bottom + 8),
      Offset(page.getClientSize().width, metaLayout.bounds.bottom + 8),
    );

    // Body content layout
    final bodyElement = PdfTextElement(
      text: translatedText,
      font: font,
      brush: PdfSolidBrush(PdfColor(30, 31, 42)),
    );

    final format = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    bodyElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, metaLayout.bounds.bottom + 18,
          page.getClientSize().width, page.getClientSize().height),
      format: format,
    );

    final outputBytes = Uint8List.fromList(pdfDocument.saveSync());
    final pageCount = pdfDocument.pages.count;
    pdfDocument.dispose();

    final name = outputName?.trim().isNotEmpty == true
        ? (outputName!.endsWith('.pdf') ? outputName : '$outputName.pdf')
        : FileUtils.generateOutputFileName(
            'Translated_${targetLanguage.toUpperCase()}');

    return await _fileService.savePdfBytes(
      outputBytes,
      name,
      operationType: 'Translated',
      pageCount: pageCount,
    );
  }

  /// Saves translated text as a .txt document in app storage
  Future<File> saveAsTxt({
    required String translatedText,
    required String originalFileName,
    required String targetLanguage,
    String? outputName,
  }) async {
    final baseDir = await _fileService.getAppPdfDirectory();
    final name = outputName?.trim().isNotEmpty == true
        ? (outputName!.endsWith('.txt') ? outputName : '$outputName.txt')
        : FileUtils.generateOutputFileName(
            'Translated_${targetLanguage.toUpperCase()}', 'txt');

    final targetFile = File('${baseDir.path}${Platform.pathSeparator}$name');
    await targetFile.writeAsString(translatedText, flush: true);

    // Register with StorageService
    final stat = await targetFile.stat();
    final model = PdfFileModel(
      id: '${targetFile.path}_${stat.modified.millisecondsSinceEpoch}',
      name: name,
      path: targetFile.path,
      size: stat.size,
      lastModified: stat.modified,
      operationType: 'Translated',
    );
    await _storage.addSavedFile(model);

    return targetFile;
  }

  List<String> _splitIntoChunks(String text, int maxChunkSize) {
    if (text.length <= maxChunkSize) return [text];
    final chunks = <String>[];
    final paragraphs = text.split('\n');
    final current = StringBuffer();

    for (final p in paragraphs) {
      if (current.length + p.length > maxChunkSize && current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current.clear();
      }
      current.writeln(p);
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }
    return chunks;
  }
}
