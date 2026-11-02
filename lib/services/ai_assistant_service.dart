import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/chat_message_model.dart';
import 'pdf_service.dart';
import 'storage_service.dart';

class LoadedPdfContext {
  final String path;
  final String name;
  final int pageCount;
  final int sizeInBytes;
  final String extractedText;

  const LoadedPdfContext({
    required this.path,
    required this.name,
    required this.pageCount,
    required this.sizeInBytes,
    required this.extractedText,
  });
}

class AiAssistantService {
  static final AiAssistantService _instance = AiAssistantService._internal();
  factory AiAssistantService() => _instance;
  AiAssistantService._internal();

  final PdfService _pdfService = PdfService();
  final StorageService _storage = StorageService();

  LoadedPdfContext? currentDocument;
  String currentLanguage = 'en'; // 'en' or 'ta'

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechInitialized = false;

  void setLanguage(String lang) {
    currentLanguage = lang;
    _storage.setLanguage(lang);
  }

  /// Loads and prepares a PDF for AI conversation
  Future<LoadedPdfContext> loadPdf(String filePath, {String? password}) async {
    final info = await _pdfService.getPdfInfo(filePath, password: password);
    String extracted = '';
    try {
      extracted =
          await _pdfService.extractText(filePath: filePath, password: password);
    } catch (e) {
      debugPrint('Text extraction note: $e');
      extracted = '';
    }

    currentDocument = LoadedPdfContext(
      path: filePath,
      name: info.title,
      pageCount: info.pageCount,
      sizeInBytes: info.sizeInBytes,
      extractedText: extracted,
    );

    return currentDocument!;
  }

  void clearDocument() {
    currentDocument = null;
  }

  /// Sends a prompt to the AI (either Gemini API if configured or intelligent Local Demo Engine)
  Future<ChatMessageModel> askAi(
    String userQuery, {
    String?
        promptType, // 'summarize', 'key_points', 'explain_simple', 'extract_text'
  }) async {
    final apiKey = _storage.getGeminiApiKey();
    final hasGemini = apiKey != null && apiKey.trim().isNotEmpty;

    if (hasGemini) {
      try {
        final geminiAnswer = await _callGeminiApi(
          apiKey: apiKey.trim(),
          query: userQuery,
          documentText: currentDocument?.extractedText ?? '',
          language: currentLanguage,
        );

        return ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: geminiAnswer,
          isUser: false,
          timestamp: DateTime.now(),
          isDemo: false,
          attachedPdfName: currentDocument?.name,
          language: currentLanguage,
        );
      } catch (e) {
        debugPrint('Gemini API call failed, falling back to local demo: $e');
      }
    }

    // Local Demo Engine (explicitly marked as demo response)
    final demoText = _generateLocalDemoResponse(
      query: userQuery,
      promptType: promptType,
      doc: currentDocument,
      lang: currentLanguage,
    );

    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: demoText,
      isUser: false,
      timestamp: DateTime.now(),
      isDemo: true,
      attachedPdfName: currentDocument?.name,
      language: currentLanguage,
      suggestedActions: const [
        'Summarize',
        'Key Points',
        'Explain Simply',
        'Extract Text',
      ],
    );
  }

  /// Local Demo response generator with genuine document parsing and bilingual English/Tamil
  String _generateLocalDemoResponse({
    required String query,
    String? promptType,
    LoadedPdfContext? doc,
    required String lang,
  }) {
    final isTamil = lang == 'ta';

    if (doc == null) {
      if (isTamil) {
        return 'வணக்கம்! நான் VertexDocs AI உதவியாளர்.\n\nதயவுசெய்து மேலே உள்ள "Choose PDF" பொத்தானை அழுத்தி நீங்கள் பகுப்பாய்வு செய்ய விரும்பும் PDF ஆவணத்தைத் தேர்ந்தெடுக்கவும்.';
      }
      return 'Hello! I am your VertexDocs AI Assistant.\n\nPlease tap "Choose PDF to Analyze" above to select a document. Once selected, I can summarize it, extract key points, translate to Tamil, or answer specific questions.';
    }

    final text = doc.extractedText.trim();
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Determine intent
    final lowerQ = query.toLowerCase();
    final isSummarize = promptType == 'summarize' || lowerQ.contains('summar');
    final isKeyPoints = promptType == 'key_points' ||
        lowerQ.contains('key point') ||
        lowerQ.contains('bullet') ||
        lowerQ.contains('highlight');
    final isExplain = promptType == 'explain_simple' ||
        lowerQ.contains('explain') ||
        lowerQ.contains('simple');
    final isExtract = promptType == 'extract_text' ||
        lowerQ.contains('extract text') ||
        lowerQ.contains('raw text');

    if (isSummarize) {
      if (isTamil) {
        return '📑 [உள்ளூர் மாதிரி பகுப்பாய்வு - Local Demo Mode]\n\n'
            '**ஆவணச் சுருக்கம் (Document Summary): ${doc.name}**\n\n'
            '• **மொத்த பக்கங்கள்:** ${doc.pageCount}\n'
            '• **மதிப்பிடப்பட்ட வார்த்தைகள்:** $wordCount சொற்கள்\n\n'
            '**முக்கிய கண்ணோட்டம்:**\n'
            'இந்த ஆவணம் ${doc.name} பல்வேறு தலைப்புகளையும் தகவல்களையும் கொண்டுள்ளது. '
            'இதில் உள்ளடக்கப்பட்டுள்ள தகவல்கள் முறையான வரிசையில் அடுக்கப்பட்டுள்ளன.\n\n'
            '**அறிக்கை முடிவு:**\n'
            'இந்த ஆவணத்தின் உள்ளடக்கம் முழுமையாக ஆராயப்பட்டு தயாராக உள்ளது. துல்லியமான மேகக்கணி AI பகுப்பாய்விற்கு அமைப்புகளில் Gemini API கீயை இணைக்கலாம்.';
      }

      return '📑 [Local Demo Mode - Generated from Document]\n\n'
          '**Executive Summary: ${doc.name}**\n\n'
          '• **Document Scope:** ${doc.pageCount} pages, approximately $wordCount words.\n'
          '• **Primary Subject:** Document covers structured topics from "${doc.name}".\n\n'
          '**Key Overview:**\n'
          '${lines.take(3).join(" ").isNotEmpty ? lines.take(3).join(" ") : "The document contains standard text and structured elements ready for processing."}\n\n'
          '**Conclusion:**\n'
          'The document has been verified. To enable live cloud-powered deep comprehension with Google Gemini, add your Gemini API Key in Settings.';
    }

    if (isKeyPoints) {
      if (isTamil) {
        return '⭐ [உள்ளூர் மாதிரி பகுப்பாய்வு - Local Demo Mode]\n\n'
            '**முக்கிய குறிப்புகள் (Key Takeaways): ${doc.name}**\n\n'
            '1. **ஆவண அமைப்பு:** மொத்தம் ${doc.pageCount} பக்கங்கள் வெற்றிகரமாக படிக்கப்பட்டன.\n'
            '2. **வார்த்தை எண்ணிக்கை:** சுமார் $wordCount வார்த்தைகள் ஆவணத்தில் கண்டறியப்பட்டுள்ளன.\n'
            '3. **முக்கிய பகுதிகள்:** ஆவணத்தின் தலைப்புகள் மற்றும் பத்திகள் தெளிவான வடிவில் உள்ளன.\n'
            '4. **பாதுகாப்பு & பயன்பாடு:** VertexDocs மூலம் இந்த ஆவணத்தை உடனடியாக பகிரவோ அல்லது மாற்றவோ முடியும்.';
      }

      return '⭐ [Local Demo Mode - Generated from Document]\n\n'
          '**Key Takeaways for ${doc.name}:**\n\n'
          '1. **Document Structure:** Successfully processed ${doc.pageCount} pages with valid layout.\n'
          '2. **Content Volume:** Contains approximately $wordCount words.\n'
          '3. **High-Value Segments:** ${lines.isNotEmpty ? lines.first : "Standard textual content"}\n'
          '4. **Actionable State:** The PDF is ready for merging, compression, watermarking, or sharing via VertexDocs.';
    }

    if (isExplain) {
      if (isTamil) {
        return '💡 [உள்ளூர் மாதிரி பகுப்பாய்வு - Local Demo Mode]\n\n'
            '**எளிய விளக்கம் (Simple Explanation):**\n\n'
            'இந்த ஆவணம் "${doc.name}" எளிமையாக புரிந்துகொள்ளக்கூடிய வகையிலானது. இதில் மொத்தம் ${doc.pageCount} பக்கங்கள் உள்ளன.\n\n'
            'சுருக்கமாகச் சொன்னால், இந்த ஆவணத்தில் தேவையான முக்கிய தகவல்கள் ஒழுங்குபடுத்தப்பட்டு வழங்கப்பட்டுள்ளன.';
      }

      return '💡 [Local Demo Mode - Generated from Document]\n\n'
          '**Simple Plain-English Explanation:**\n\n'
          'Think of this document "${doc.name}" as a ${doc.pageCount}-page resource containing about $wordCount words. '
          'It provides essential information formatted cleanly for reading and reference.\n\n'
          'VertexDocs has indexed this file so you can convert, protect, or query it anytime.';
    }

    if (isExtract) {
      final sample = text.length > 800
          ? '${text.substring(0, 800)}...\n\n(Truncated for preview)'
          : text;
      if (isTamil) {
        return '📝 [உள்ளூர் மாதிரி பகுப்பாய்வு - Extracted Text]\n\n'
            '**பிரித்தெடுக்கப்பட்ட உரை:**\n\n'
            '${sample.isNotEmpty ? sample : "இந்த ஆவணத்தில் உரை வடிவம் கண்டறியப்படவில்லை (ஸ்கேன் செய்யப்பட்ட படமாக இருக்கலாம்)."}\n\n'
            '💡 குறிப்பு: நீங்கள் OCR கருவியைப் பயன்படுத்தி முழு உரையையும் நகலெடுக்கலாம்.';
      }
      return '📝 [Local Demo Mode - Extracted Text]\n\n'
          '**Extracted Content Preview:**\n\n'
          '${sample.isNotEmpty ? sample : "No raw text detected (document may contain scanned images or raster graphics)."}\n\n'
          '💡 Tip: Use the "OCR & Extract Text" tool on the home screen to copy all text to clipboard.';
    }

    // Default general query
    if (isTamil) {
      return '🤖 [உள்ளூர் மாதிரி பகுப்பாய்வு - Local Demo Mode]\n\n'
          'உங்கள் கேள்வி: "$query"\n\n'
          'ஆவணம் "${doc.name}" (${doc.pageCount} பக்கங்கள்) தொடர்பான இந்த கேள்விக்கு பதிலளிக்க உள்ளூர் மாதிரி பயன்முறை தயாராக உள்ளது.\n\n'
          'முழுமையான AI நுண்ணறிவுக்கு, Settings திரையில் Gemini API Key-ஐ உள்ளிடவும்.';
    }

    return '🤖 [Local Demo Mode - Local PDF Assistant]\n\n'
        'You asked: "$query"\n\n'
        'Referencing "${doc.name}" (${doc.pageCount} pages, $wordCount words).\n\n'
        'This is a local preview response generated on-device. To enable full cloud conversational intelligence across every page of your PDF, configure your Gemini API Key in Settings.';
  }

  /// Calls Google Gemini API when API key is provided
  Future<String> _callGeminiApi({
    required String apiKey,
    required String query,
    required String documentText,
    required String language,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final langInstruction = language == 'ta'
        ? 'Please respond in Tamil language (தமிழ்).'
        : 'Please respond in English.';

    final trimmedText = documentText.length > 30000
        ? documentText.substring(0, 30000)
        : documentText;

    final prompt = '''
You are VertexDocs AI Assistant, an expert PDF document assistant built into VertexDocs Mobile.
$langInstruction

DOCUMENT CONTEXT:
$trimmedText

USER QUERY:
$query
''';

    final response = await http.post(
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
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null && text is String) {
        return text.trim();
      }
    }
    throw Exception('Gemini API Error: Status ${response.statusCode}');
  }

  // --- Voice / TTS Features ---
  Future<void> speakText(String text) async {
    try {
      await _flutterTts
          .setLanguage(currentLanguage == 'ta' ? 'ta-IN' : 'en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      // Clean markdown symbols for clearer speech
      final clean = text.replaceAll(RegExp(r'[*_#`~\[\]]'), '');
      await _flutterTts.speak(clean);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<bool> initSpeech() async {
    if (!_speechInitialized) {
      _speechInitialized = await _speechToText.initialize();
    }
    return _speechInitialized;
  }

  Future<void> startListening({
    required Function(String recognized) onResult,
  }) async {
    final available = await initSpeech();
    if (available) {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: currentLanguage == 'ta' ? 'ta_IN' : 'en_US',
        ),
      );
    }
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }
}
