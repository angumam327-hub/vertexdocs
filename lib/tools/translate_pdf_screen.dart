import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_assistant_service.dart';
import '../services/ai_pdf_intelligence_service.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class TranslatePdfScreen extends StatefulWidget {
  final File? initialFile;

  const TranslatePdfScreen({super.key, this.initialFile});

  @override
  State<TranslatePdfScreen> createState() => _TranslatePdfScreenState();
}

class _TranslatePdfScreenState extends State<TranslatePdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  String _sourceLang = 'Auto-Detect';
  String _targetLang = 'Tamil';
  AiIntelligenceResult? _result;
  bool _isSpeaking = false;

  final List<String> _languages = [
    'Auto-Detect',
    'English',
    'Tamil',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Chinese',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    AiAssistantService().stopSpeaking();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _result = null;
    });
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;
    setState(() => _pdfInfo = info);
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processTranslate() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final res = await AiPdfIntelligenceService().translate(
        filePath: _selectedFile!.path,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Translation error: $e')),
      );
    }
  }

  void _toggleSpeak() async {
    if (_result == null) return;
    if (_isSpeaking) {
      await AiAssistantService().stopSpeaking();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await AiAssistantService().speakText(_result!.content);
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _copyResult() {
    if (_result == null) return;
    Clipboard.setData(ClipboardData(text: _result!.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Translated text copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate PDF'),
        actions: [
          if (_result != null) ...[
            IconButton(
              icon: Icon(
                  _isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.volume_mute_rounded,
                  color: AppColors.primary),
              tooltip: _isSpeaking ? 'Stop Audio' : 'Listen Aloud',
              onPressed: _toggleSpeak,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              tooltip: 'Copy',
              onPressed: _copyResult,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              tooltip: 'Share',
              onPressed: () =>
                  ShareService.shareFile('', text: _result!.content),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tool Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.translate_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Translate Document',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Translate contracts and documents between English, Tamil, and international languages.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // File selection
            if (_selectedFile == null) ...[
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select PDF Document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose document to translate.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // File Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FileUtils.getFileName(_selectedFile!.path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_pdfInfo?.pageCount ?? 1} pages • ${FileUtils.formatFileSize(_selectedFile!.lengthSync())}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                        onPressed: _pickFile, child: const Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Language Pickers Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Language Pair',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sourceLang,
                            decoration: InputDecoration(
                              labelText: 'From',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _languages
                                .map((l) =>
                                    DropdownMenuItem(value: l, child: Text(l)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _sourceLang = v);
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primary),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _targetLang,
                            decoration: InputDecoration(
                              labelText: 'To',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _languages
                                .where((l) => l != 'Auto-Detect')
                                .map((l) =>
                                    DropdownMenuItem(value: l, child: Text(l)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _targetLang = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              GradientButton(
                text: 'Translate PDF to $_targetLang',
                icon: Icons.g_translate_rounded,
                isLoading: _isProcessing,
                onPressed: _processTranslate,
              ),

              // Translation Result Card
              if (_result != null) ...[
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _result!.title,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _result!.isDemo
                                  ? AppColors.surface
                                  : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _result!.isDemo ? 'Demo Mode' : 'Gemini AI',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _result!.isDemo
                                    ? AppColors.primary
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      SelectableText(
                        _result!.content,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
