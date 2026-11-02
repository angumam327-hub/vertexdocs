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

class _QaItem {
  final String question;
  final String answer;
  final bool isDemo;

  _QaItem({required this.question, required this.answer, required this.isDemo});
}

class PdfQaScreen extends StatefulWidget {
  final File? initialFile;

  const PdfQaScreen({super.key, this.initialFile});

  @override
  State<PdfQaScreen> createState() => _PdfQaScreenState();
}

class _PdfQaScreenState extends State<PdfQaScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;
  String _language = 'en';

  final TextEditingController _questionController = TextEditingController();
  final List<_QaItem> _qaHistory = [];

  final List<String> _suggestedQuestions = [
    'What is the primary objective of this document?',
    'Are there any key dates, deadlines, or timelines?',
    'What are the obligations or action items specified?',
    'Explain the summary in simple words.',
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
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _qaHistory.clear();
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

  Future<void> _askQuestion(String question) async {
    if (_selectedFile == null) return;
    final q = question.trim();
    if (q.isEmpty) return;

    _questionController.clear();
    setState(() => _isProcessing = true);

    try {
      final res = await AiPdfIntelligenceService().answerQuestion(
        filePath: _selectedFile!.path,
        question: q,
        language: _language,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _qaHistory.insert(
            0,
            _QaItem(
              question: q,
              answer: res.content,
              isDemo: res.isDemo,
            ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Q&A Assistant'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language_rounded, color: AppColors.primary),
            tooltip: 'Language',
            onSelected: (val) => setState(() => _language = val),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'en',
                  child: Text('English ${_language == "en" ? "✓" : ""}')),
              PopupMenuItem(
                  value: 'ta',
                  child: Text('தமிழ் ${_language == "ta" ? "✓" : ""}')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                          child: const Icon(Icons.quiz_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interactive Document Q&A',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Ask questions directly grounded in the content of your PDF.',
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 20),
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
                              'Choose a document to begin asking questions.',
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_pdfInfo?.pageCount ?? 1} pages • ${FileUtils.formatFileSize(_selectedFile!.lengthSync())}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Suggested Prompts
                    Text(
                      'Suggested Questions',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedQuestions
                          .map((q) => ActionChip(
                                label: Text(q,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12)),
                                onPressed: _isProcessing
                                    ? null
                                    : () => _askQuestion(q),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                    color: AppColors.cardBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),

                    // QA History
                    if (_isProcessing) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                    ],

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _qaHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = _qaHistory[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.help_outline_rounded,
                                      color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.question,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.isDemo
                                          ? AppColors.surface
                                          : AppColors.success
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.isDemo ? 'Demo' : 'AI',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: item.isDemo
                                            ? AppColors.primary
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              SelectableText(
                                item.answer,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.volume_up_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                    tooltip: 'Listen',
                                    onPressed: () => AiAssistantService()
                                        .speakText(item.answer),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                    tooltip: 'Copy',
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: item.answer));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            backgroundColor: AppColors.success,
                                            content: Text('Copied!')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                    tooltip: 'Share',
                                    onPressed: () => ShareService.shareFile('',
                                        text: item.answer),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Input Field
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        onSubmitted: _askQuestion,
                        decoration: InputDecoration(
                          hintText: 'Ask any question about this PDF...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          isDense: true,
                          prefixIcon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _isProcessing
                          ? null
                          : () => _askQuestion(_questionController.text),
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
