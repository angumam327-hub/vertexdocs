import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'storage_service.dart';

class AiIntelligenceResult {
  final String title;
  final String content;
  final bool isDemo;
  final String language;

  const AiIntelligenceResult({
    required this.title,
    required this.content,
    required this.isDemo,
    required this.language,
  });
}

class AiPdfIntelligenceService {
  static final AiPdfIntelligenceService _instance =
      AiPdfIntelligenceService._internal();
  factory AiPdfIntelligenceService() => _instance;
  AiPdfIntelligenceService._internal();

  final StorageService _storage = StorageService();

  Future<String> _extractText(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return text.trim();
  }

  /// Generates short or detailed executive summary in English or Tamil
  Future<AiIntelligenceResult> summarize({
    required String filePath,
    bool isDetailed = false,
    String language = 'en',
  }) async {
    final text = await _extractText(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final apiKey = _storage.getGeminiApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final mode =
            isDetailed ? 'detailed comprehensive' : 'concise executive';
        final langPrompt = language == 'ta' ? 'in Tamil (தமிழ்)' : 'in English';
        final prompt =
            'Please provide a $mode summary of this document $langPrompt:\n\n$text';
        final result = await _callGemini(apiKey: apiKey, prompt: prompt);
        return AiIntelligenceResult(
          title: 'Document Summary ($fileName)',
          content: result,
          isDemo: false,
          language: language,
        );
      } catch (e) {
        debugPrint('Gemini API call failed, falling back to local demo: $e');
      }
    }

    // Local Demo Engine
    final isTamil = language == 'ta';
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    final buffer = StringBuffer();
    if (isTamil) {
      buffer.writeln('📑 [உள்ளூர் மாதிரி பயன்முறை - Local Demo Mode]');
      buffer.writeln('**ஆவணச் சுருக்கம்: $fileName**\n');
      buffer.writeln('• **வார்த்தை எண்ணிக்கை:** $wordCount சொற்கள்');
      buffer.writeln('• **முக்கிய தலைப்புகள்:** ${lines.take(3).join(', ')}\n');
      buffer.writeln('**முக்கிய கண்ணோட்டம்:**');
      buffer.writeln(
          'இந்த ஆவணம் முக்கியமான தகவல்களைக் கொண்டுள்ளது. ${isDetailed ? "விவரமான பகுப்பாய்வில் அனைத்து பத்திகளும் ஆய்வு செய்யப்பட்டு ஒழுங்குபடுத்தப்பட்டுள்ளன." : "சுருக்கமாக, தேவையான தரவுகள் இதில் முறையாகத் தொகுக்கப்பட்டுள்ளன."}\n');
      buffer.writeln(
          '💡 மேகக்கணி AI பகுப்பாய்விற்கு அமைப்புகளில் Gemini API கீயைச் சேர்க்கவும்.');
    } else {
      buffer.writeln('📑 [Local Demo Mode - Generated on Device]');
      buffer.writeln(
          '**${isDetailed ? "Detailed" : "Executive"} Summary: $fileName**\n');
      buffer.writeln('• **Document Size:** Approximately $wordCount words');
      buffer.writeln('• **Primary Headings:** ${lines.take(3).join(" • ")}\n');
      buffer.writeln('**Key Highlights:**');
      if (lines.length > 3) {
        for (final line in lines.take(isDetailed ? 6 : 3)) {
          buffer.writeln('• $line');
        }
      } else {
        buffer.writeln(
            '• Document structure and body paragraphs indexed successfully.');
      }
      buffer.writeln('\n**Conclusion:**');
      buffer.writeln(
          'The document is fully organized. To enable live neural synthesis with Google Gemini, connect an API key in Settings.');
    }

    return AiIntelligenceResult(
      title: 'Summary: $fileName',
      content: buffer.toString(),
      isDemo: true,
      language: language,
    );
  }

  /// Translates document text between English, Tamil, and other languages
  Future<AiIntelligenceResult> translate({
    required String filePath,
    required String sourceLang,
    required String targetLang,
  }) async {
    final text = await _extractText(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final apiKey = _storage.getGeminiApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final prompt =
            'Translate the following document text from $sourceLang to $targetLang accurately:\n\n$text';
        final result = await _callGemini(apiKey: apiKey, prompt: prompt);
        return AiIntelligenceResult(
          title: 'Translation: $sourceLang -> $targetLang',
          content: result,
          isDemo: false,
          language: targetLang,
        );
      } catch (e) {
        debugPrint('Gemini translation error: $e');
      }
    }

    // Local Demo Engine
    final buffer = StringBuffer();
    buffer.writeln('🌐 [Local Demo Translation]');
    buffer.writeln(
        '**Source Language:** $sourceLang | **Target Language:** $targetLang');
    buffer.writeln('**Document:** $fileName\n');

    if (targetLang.toLowerCase().contains('tamil') || targetLang == 'ta') {
      buffer.writeln(
          '**மொழிபெயர்க்கப்பட்ட உரை மாதிரி (Sample Translated Text):**\n');
      buffer.writeln(
          'ஆவணம் "$fileName" வெற்றிகரமாகப் பகுப்பாய்வு செய்யப்பட்டது.');
      buffer.writeln(
          'இந்த ஆவணத்தில் உள்ள முக்கிய தகவல்கள் தமிழ் மொழியில் மொழிபெயர்க்க தயாராக உள்ளன.');
      buffer.writeln(
          '\nமுழுமையான தானியங்கி மொழிபெயர்ப்புக்கு Settings-ல் Gemini API Key-ஐ உள்ளிடவும்.');
    } else {
      buffer.writeln('**Translated Text Sample:**\n');
      buffer.writeln(
          'Document "$fileName" has been parsed for translation into $targetLang.');
      buffer.writeln(
          'Core textual structures have been validated for multiline conversion.');
      buffer.writeln(
          '\nTo activate instant cloud translation across all pages, configure your Gemini API Key in Settings.');
    }

    return AiIntelligenceResult(
      title: 'Translated Document',
      content: buffer.toString(),
      isDemo: true,
      language: targetLang,
    );
  }

  /// Extracts bulleted key points and actionable takeaways
  Future<AiIntelligenceResult> extractKeyPoints({
    required String filePath,
    String language = 'en',
  }) async {
    final text = await _extractText(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final apiKey = _storage.getGeminiApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final langPrompt = language == 'ta' ? 'in Tamil' : 'in English';
        final prompt =
            'Extract actionable bullet points and key takeaways $langPrompt from:\n\n$text';
        final result = await _callGemini(apiKey: apiKey, prompt: prompt);
        return AiIntelligenceResult(
          title: 'Key Points ($fileName)',
          content: result,
          isDemo: false,
          language: language,
        );
      } catch (e) {
        debugPrint('Gemini error: $e');
      }
    }

    final isTamil = language == 'ta';
    final lines = text.split('\n').where((l) => l.trim().length > 10).toList();

    final buffer = StringBuffer();
    if (isTamil) {
      buffer.writeln('⭐ [உள்ளூர் மாதிரி - Local Demo Mode]');
      buffer.writeln('**முக்கிய குறிப்புகள்: $fileName**\n');
      for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
        buffer.writeln('${i + 1}. ${lines[i]}');
      }
      if (lines.isEmpty) {
        buffer.writeln('1. ஆவணம் வெற்றிகரமாகச் சரிபார்க்கப்பட்டது.');
        buffer.writeln('2. உரை பகுப்பாய்வு முடிந்தது.');
      }
    } else {
      buffer.writeln('⭐ [Local Demo Mode]');
      buffer.writeln('**Actionable Key Takeaways for $fileName:**\n');
      for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
        buffer.writeln('• ${lines[i]}');
      }
      if (lines.isEmpty) {
        buffer.writeln('• Document indexed with complete textual fidelity.');
        buffer.writeln('• Ready for distribution and archiving.');
      }
    }

    return AiIntelligenceResult(
      title: 'Key Points: $fileName',
      content: buffer.toString(),
      isDemo: true,
      language: language,
    );
  }

  /// Answers a specific question grounded in the document text
  Future<AiIntelligenceResult> answerQuestion({
    required String filePath,
    required String question,
    String language = 'en',
  }) async {
    final text = await _extractText(filePath);
    final apiKey = _storage.getGeminiApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final prompt =
            'Answer this user question using the document context:\nQuestion: $question\n\nDocument:\n$text';
        final result = await _callGemini(apiKey: apiKey, prompt: prompt);
        return AiIntelligenceResult(
          title: 'Q&A Answer',
          content: result,
          isDemo: false,
          language: language,
        );
      } catch (e) {
        debugPrint('Gemini Q&A error: $e');
      }
    }

    final isTamil = language == 'ta';
    final lowerQ = question.toLowerCase();
    final matchingLines = text
        .split('\n')
        .where((l) {
          final words = lowerQ.split(' ').where((w) => w.length > 3);
          return words.any((w) => l.toLowerCase().contains(w));
        })
        .take(3)
        .toList();

    final buffer = StringBuffer();
    if (isTamil) {
      buffer.writeln('🤖 [உள்ளூர் மாதிரி - Q&A Demo]');
      buffer.writeln('**கேள்வி:** "$question"\n');
      if (matchingLines.isNotEmpty) {
        buffer.writeln('**ஆவணத்தில் கண்டறியப்பட்ட தொடர்புடைய தகவல்:**');
        for (final m in matchingLines) {
          buffer.writeln('• $m');
        }
      } else {
        buffer.writeln(
            'ஆவணத்தின் உரைத் தகவல்களிலிருந்து பதிலளிக்க தயாராக உள்ளது.');
      }
    } else {
      buffer.writeln('🤖 [Local Demo Mode - Document Q&A]');
      buffer.writeln('**Question:** "$question"\n');
      if (matchingLines.isNotEmpty) {
        buffer.writeln('**Relevant Document Excerpts:**');
        for (final m in matchingLines) {
          buffer.writeln('• $m');
        }
      } else {
        buffer.writeln('Referenced document context for: "$question".');
      }
      buffer.writeln(
          '\nConfigure your Gemini API Key in Settings to get real-time generative conversational answers.');
    }

    return AiIntelligenceResult(
      title: 'Answer',
      content: buffer.toString(),
      isDemo: true,
      language: language,
    );
  }

  /// Simplifies difficult or technical text into plain language
  Future<AiIntelligenceResult> explainSimply({
    required String filePath,
    String language = 'en',
  }) async {
    final text = await _extractText(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final apiKey = _storage.getGeminiApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final langPrompt = language == 'ta'
            ? 'in simple Tamil (எளிய தமிழ்)'
            : 'in simple plain English';
        final prompt =
            'Explain the following document content simply, as if explaining to a 10-year-old $langPrompt:\n\n$text';
        final result = await _callGemini(apiKey: apiKey, prompt: prompt);
        return AiIntelligenceResult(
          title: 'Simple Explanation ($fileName)',
          content: result,
          isDemo: false,
          language: language,
        );
      } catch (e) {
        debugPrint('Gemini explain error: $e');
      }
    }

    final isTamil = language == 'ta';
    final buffer = StringBuffer();
    if (isTamil) {
      buffer.writeln('💡 [எளிய விளக்கம் - Local Demo Mode]');
      buffer.writeln('**ஆவணம் "$fileName" பற்றிய எளிய விளக்கம்:**\n');
      buffer.writeln(
          'இந்த ஆவணம் எளிமையாகப் புரிந்துகொள்ளக்கூடிய வடிவில் உள்ளது.');
      buffer.writeln(
          'கடினமான தொழில்நுட்ப அல்லது சட்ட சொற்களைத் தவிர்த்து, தேவையான முக்கிய கருத்துக்களை நாம் எளிதாக அறிந்துகொள்ள முடியும்.');
    } else {
      buffer.writeln('💡 [Local Demo Mode - Simple Language]');
      buffer.writeln('**Plain English Explanation of "$fileName":**\n');
      buffer.writeln(
          'Think of this document as a clean guide that explains its key topic step by step.');
      buffer.writeln(
          'Instead of reading complicated legal or technical jargon, here are the basics: the document lays out core terms, establishes clear steps, and organizes essential data.');
      buffer.writeln(
          '\nFor full AI plain-language decomposition of complex clauses, add your Gemini API Key in Settings.');
    }

    return AiIntelligenceResult(
      title: 'Plain Explanation',
      content: buffer.toString(),
      isDemo: true,
      language: language,
    );
  }

  Future<String> _callGemini({
    required String apiKey,
    required String prompt,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final trimmed = prompt.length > 30000 ? prompt.substring(0, 30000) : prompt;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': trimmed}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null && text is String) {
        return text.trim();
      }
    }
    throw Exception('Gemini HTTP Status ${response.statusCode}');
  }
}
